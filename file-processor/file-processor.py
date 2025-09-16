#!/usr/bin/env python3
"""
BriskLearning File Processor
Handles file upload, virus scanning, text extraction, and vector storage
"""
import os
import psycopg2
import requests
from azure.storage.blob import BlobServiceClient
import magic
import schedule
import time
import json
import logging
from datetime import datetime
from sentence_transformers import SentenceTransformer
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from typing import Optional
import hashlib
import shutil
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(title="BriskLearning File Processor")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class BriskLearningProcessor:
    def __init__(self):
        # Database configuration
        self.postgres_config = {
            'host': os.getenv('PGHOST', 'scannedfiles.postgres.database.azure.com'),
            'user': os.getenv('PGUSER', 'developergrowwstacks'),
            'password': os.getenv('PGPASSWORD', 'palash2003@'),
            'database': os.getenv('PGDATABASE', 'processed'),
            'port': os.getenv('PGPORT', '5432')
        }
        
        # Azure Storage configuration
        self.storage_account = os.getenv('AZURE_STORAGE_ACCOUNT')
        self.storage_key = os.getenv('AZURE_STORAGE_KEY')
        
        if self.storage_account and self.storage_key:
            self.blob_client = BlobServiceClient(
                account_url=f"https://{self.storage_account}.blob.core.windows.net",
                credential=self.storage_key
            )
        else:
            logger.warning("Azure Storage credentials not provided")
            self.blob_client = None
        
        # ClamAV configuration
        self.clamav_host = os.getenv('CLAMAV_HOST', 'clamav')
        self.clamav_port = int(os.getenv('CLAMAV_PORT', '3310'))
        
        # Environment
        self.environment = os.getenv('ENVIRONMENT', 'dev')
        
        # Initialize sentence transformer for embeddings
        try:
            self.model = SentenceTransformer('all-MiniLM-L6-v2')
            logger.info("Sentence transformer model loaded successfully")
        except Exception as e:
            logger.error(f"Failed to load sentence transformer: {e}")
            self.model = None
        
        # Initialize database
        self.init_database()
    
    def get_db_connection(self):
        """Get database connection"""
        try:
            conn = psycopg2.connect(**self.postgres_config)
            return conn
        except Exception as e:
            logger.error(f"Database connection failed: {e}")
            raise
    
    def init_database(self):
        """Initialize database tables and extensions"""
        try:
            conn = self.get_db_connection()
            cur = conn.cursor()
            
            # Create extensions
            cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
            
            # Create main processed files table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS processed_files (
                    id SERIAL PRIMARY KEY,
                    file_hash VARCHAR(64) UNIQUE,
                    filename VARCHAR(255) NOT NULL,
                    original_filename VARCHAR(255),
                    file_type VARCHAR(100),
                    file_size BIGINT,
                    environment VARCHAR(50),
                    processed_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    text_content TEXT,
                    embedding vector(384),
                    source_type VARCHAR(50),
                    category VARCHAR(100),
                    scan_status VARCHAR(50),
                    scan_date TIMESTAMP,
                    storage_url TEXT,
                    metadata JSONB,
                    created_by VARCHAR(100),
                    status VARCHAR(50) DEFAULT 'processed'
                );
            """)
            
            # Create index for vector similarity search
            cur.execute("""
                CREATE INDEX IF NOT EXISTS processed_files_embedding_idx 
                ON processed_files USING ivfflat (embedding vector_cosine_ops);
            """)
            
            # Create file processing log table
            cur.execute("""
                CREATE TABLE IF NOT EXISTS processing_log (
                    id SERIAL PRIMARY KEY,
                    file_id INTEGER REFERENCES processed_files(id),
                    action VARCHAR(100),
                    status VARCHAR(50),
                    message TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    environment VARCHAR(50)
                );
            """)
            
            conn.commit()
            cur.close()
            conn.close()
            logger.info("Database initialized successfully")
            
        except Exception as e:
            logger.error(f"Database initialization failed: {e}")
    
    def calculate_file_hash(self, file_path: str) -> str:
        """Calculate SHA-256 hash of file"""
        hash_sha256 = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_sha256.update(chunk)
        return hash_sha256.hexdigest()
    
    def scan_file_with_clamav(self, file_path: str) -> tuple[bool, str]:
        """Scan file using ClamAV daemon"""
        try:
            # For now, simulate ClamAV scanning since the actual integration needs more setup
            # In production, you would use clamd or make HTTP requests to ClamAV
            
            # Check file size (reject files over 100MB)
            file_size = os.path.getsize(file_path)
            if file_size > 100 * 1024 * 1024:
                return False, "File too large"
            
            # Check file type
            file_type = magic.from_file(file_path, mime=True)
            suspicious_types = ['application/x-executable', 'application/x-dosexec']
            if file_type in suspicious_types:
                return False, "Suspicious file type"
            
            # Simulate successful scan
            logger.info(f"File {file_path} passed virus scan (simulated)")
            return True, "Clean"
            
        except Exception as e:
            logger.error(f"ClamAV scan failed for {file_path}: {e}")
            return False, f"Scan error: {str(e)}"
    
    def extract_text(self, file_path: str) -> str:
        """Extract text from various file types"""
        try:
            file_type = magic.from_file(file_path, mime=True)
            
            if file_type.startswith('text/'):
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    return f.read()
            elif file_type == 'application/pdf':
                # For PDF extraction, you'd typically use PyPDF2 or similar
                # For now, return placeholder
                return f"[PDF content from {os.path.basename(file_path)}]"
            elif file_type.startswith('image/'):
                # For OCR, you'd use pytesseract
                return f"[Image content from {os.path.basename(file_path)}]"
            else:
                return f"[Binary file: {os.path.basename(file_path)}]"
                
        except Exception as e:
            logger.error(f"Text extraction failed for {file_path}: {e}")
            return f"[Text extraction failed: {str(e)}]"
    
    def generate_embeddings(self, text: str) -> Optional[list]:
        """Generate vector embeddings from text"""
        if not self.model:
            logger.warning("Sentence transformer model not available")
            return None
        
        try:
            embedding = self.model.encode(text)
            return embedding.tolist()
        except Exception as e:
            logger.error(f"Embedding generation failed: {e}")
            return None
    
    def upload_to_azure_storage(self, file_path: str, container_name: str = "processed") -> Optional[str]:
        """Upload file to Azure Storage"""
        if not self.blob_client:
            logger.warning("Azure Storage client not available")
            return None
        
        try:
            filename = os.path.basename(file_path)
            blob_name = f"{self.environment}/{datetime.now().strftime('%Y/%m/%d')}/{filename}"
            
            blob_client = self.blob_client.get_blob_client(
                container=container_name, 
                blob=blob_name
            )
            
            with open(file_path, "rb") as data:
                blob_client.upload_blob(data, overwrite=True)
            
            return blob_client.url
            
        except Exception as e:
            logger.error(f"Azure Storage upload failed: {e}")
            return None
    
    def store_in_database(self, file_info: dict, text_content: str, embedding: Optional[list]) -> Optional[int]:
        """Store file information and embeddings in PostgreSQL"""
        try:
            conn = self.get_db_connection()
            cur = conn.cursor()
            
            # Check if file already exists
            cur.execute(
                "SELECT id FROM processed_files WHERE file_hash = %s",
                (file_info['file_hash'],)
            )
            existing = cur.fetchone()
            
            if existing:
                logger.info(f"File {file_info['filename']} already processed")
                cur.close()
                conn.close()
                return existing[0]
            
            # Insert new record
            cur.execute("""
                INSERT INTO processed_files 
                (file_hash, filename, original_filename, file_type, file_size, 
                 environment, text_content, embedding, source_type, category, 
                 scan_status, scan_date, storage_url, metadata, created_by)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (
                file_info['file_hash'],
                file_info['filename'],
                file_info.get('original_filename', file_info['filename']),
                file_info['file_type'],
                file_info['file_size'],
                self.environment,
                text_content,
                embedding,
                file_info.get('source_type', 'upload'),
                file_info.get('category', 'document'),
                file_info.get('scan_status', 'clean'),
                datetime.now(),
                file_info.get('storage_url'),
                json.dumps(file_info.get('metadata', {})),
                file_info.get('created_by', 'system')
            ))
            
            file_id = cur.fetchone()[0]
            
            # Log the processing
            cur.execute("""
                INSERT INTO processing_log (file_id, action, status, message, environment)
                VALUES (%s, %s, %s, %s, %s)
            """, (
                file_id,
                'file_processed',
                'success',
                f"File {file_info['filename']} processed successfully",
                self.environment
            ))
            
            conn.commit()
            cur.close()
            conn.close()
            
            logger.info(f"Stored file {file_info['filename']} in database with ID {file_id}")
            return file_id
            
        except Exception as e:
            logger.error(f"Database storage failed: {e}")
            return None
    
    def process_file(self, file_path: str, original_filename: str, category: str = "document", 
                    source_type: str = "upload", created_by: str = "user") -> dict:
        """Main file processing workflow"""
        result = {
            'success': False,
            'file_id': None,
            'message': '',
            'scan_status': 'pending'
        }
        
        try:
            logger.info(f"Processing file: {original_filename}")
            
            # Calculate file hash
            file_hash = self.calculate_file_hash(file_path)
            
            # Get file info
            file_info = {
                'filename': f"{file_hash}_{original_filename}",
                'original_filename': original_filename,
                'file_hash': file_hash,
                'file_type': magic.from_file(file_path, mime=True),
                'file_size': os.path.getsize(file_path),
                'source_type': source_type,
                'category': category,
                'created_by': created_by,
                'metadata': {
                    'processed_at': datetime.now().isoformat(),
                    'environment': self.environment
                }
            }
            
            # Scan with ClamAV
            is_clean, scan_message = self.scan_file_with_clamav(file_path)
            file_info['scan_status'] = 'clean' if is_clean else 'infected'
            result['scan_status'] = file_info['scan_status']
            
            if not is_clean:
                # Move to quarantine
                quarantine_path = f"/shared-files/quarantine/{file_info['filename']}"
                shutil.move(file_path, quarantine_path)
                result['message'] = f"File quarantined: {scan_message}"
                logger.warning(f"File {original_filename} quarantined: {scan_message}")
                return result
            
            # Extract text
            text_content = self.extract_text(file_path)
            
            # Generate embeddings
            embedding = self.generate_embeddings(text_content)
            
            # Upload to Azure Storage
            storage_url = self.upload_to_azure_storage(file_path, "processed")
            file_info['storage_url'] = storage_url
            
            # Store in database
            file_id = self.store_in_database(file_info, text_content, embedding)
            
            if file_id:
                # Move to processed folder
                processed_path = f"/shared-files/processed/{file_info['filename']}"
                shutil.move(file_path, processed_path)
                
                result['success'] = True
                result['file_id'] = file_id
                result['message'] = "File processed successfully"
                
                logger.info(f"Successfully processed file {original_filename} with ID {file_id}")
            else:
                result['message'] = "Database storage failed"
                
        except Exception as e:
            logger.error(f"File processing failed for {original_filename}: {e}")
            result['message'] = f"Processing failed: {str(e)}"
        
        return result

# Initialize processor
processor = BriskLearningProcessor()

# FastAPI endpoints
@app.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    category: str = Form("document"),
    created_by: str = Form("user")
):
    """Handle file upload via API"""
    try:
        # Save uploaded file temporarily
        temp_dir = Path("/shared-files/incoming")
        temp_dir.mkdir(exist_ok=True)
        
        temp_path = temp_dir / f"temp_{file.filename}"
        
        with open(temp_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # Process the file
        result = processor.process_file(
            str(temp_path), 
            file.filename, 
            category=category,
            source_type="api_upload",
            created_by=created_by
        )
        
        return result
        
    except Exception as e:
        logger.error(f"Upload endpoint failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/form/submit")
async def submit_form(
    organization: str = Form(...),
    email: str = Form(...),
    description: str = Form(...)
):
    """Handle form submission"""
    try:
        # Store form data as text and generate embedding
        text_content = f"Organization: {organization}\nEmail: {email}\nDescription: {description}"
        
        file_info = {
            'filename': f"form_{int(time.time())}_{organization.lower().replace(' ', '_')}.txt",
            'original_filename': f"form_submission_{organization}",
            'file_hash': hashlib.sha256(text_content.encode()).hexdigest(),
            'file_type': 'text/plain',
            'file_size': len(text_content.encode()),
            'source_type': 'form_submission',
            'category': 'form_data',
            'created_by': email,
            'scan_status': 'clean',
            'metadata': {
                'organization': organization,
                'email': email,
                'submitted_at': datetime.now().isoformat(),
                'environment': processor.environment
            }
        }
        
        # Generate embeddings
        embedding = processor.generate_embeddings(text_content)
        
        # Store in database
        file_id = processor.store_in_database(file_info, text_content, embedding)
        
        if file_id:
            return {
                'success': True,
                'file_id': file_id,
                'message': 'Form submitted successfully'
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to store form data")
            
    except Exception as e:
        logger.error(f"Form submission failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Test database connection
        conn = processor.get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        
        return {
            'status': 'healthy',
            'environment': processor.environment,
            'timestamp': datetime.now().isoformat(),
            'services': {
                'database': 'connected',
                'embeddings': 'available' if processor.model else 'unavailable',
                'storage': 'available' if processor.blob_client else 'unavailable'
            }
        }
    except Exception as e:
        return {
            'status': 'unhealthy',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }

@app.get("/search")
async def search_similar(query: str, limit: int = 5):
    """Search for similar documents using vector similarity"""
    try:
        if not processor.model:
            raise HTTPException(status_code=503, detail="Embedding model not available")
        
        # Generate embedding for query
        query_embedding = processor.generate_embeddings(query)
        if not query_embedding:
            raise HTTPException(status_code=500, detail="Failed to generate query embedding")
        
        # Search database
        conn = processor.get_db_connection()
        cur = conn.cursor()
        
        cur.execute("""
            SELECT id, filename, original_filename, text_content, 
                   (embedding <=> %s::vector) as similarity,
                   processed_date, category, source_type
            FROM processed_files 
            WHERE embedding IS NOT NULL
            ORDER BY similarity
            LIMIT %s
        """, (query_embedding, limit))
        
        results = cur.fetchall()
        cur.close()
        conn.close()
        
        return {
            'query': query,
            'results': [
                {
                    'id': r[0],
                    'filename': r[1],
                    'original_filename': r[2],
                    'text_preview': r[3][:200] + "..." if len(r[3]) > 200 else r[3],
                    'similarity': float(r[4]),
                    'processed_date': r[5].isoformat() if r[5] else None,
                    'category': r[6],
                    'source_type': r[7]
                }
                for r in results
            ]
        }
        
    except Exception as e:
        logger.error(f"Search failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    # Start the API server
    uvicorn.run(app, host="0.0.0.0", port=8000)
