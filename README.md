# Agentic Infrastructure Project

This repository manages the infrastructure for the Agentic project.

## Current Setup
- ClamAV and n8n running on Azure VM
- ClamAV listening on port 3310
- n8n listening on port 5678

## Architecture Goals
```
Website Forms → Webhook → n8n → ClamAV → Azure Data Lake
```

## Environments
- **Development**: Current VM setup
- **Test**: To be created
- **Production**: To be created

## Repository Structure
```
├── terraform/           # Infrastructure as Code
├── .github/workflows/   # CI/CD pipelines
├── docs/               # Documentation
├── scripts/            # Deployment scripts
└── config/             # Configuration files
```

## Next Steps
1. Document current infrastructure
2. Create Terraform configuration for existing resources
3. Set up proper CI/CD pipeline
4. Migrate to proper container architecture
