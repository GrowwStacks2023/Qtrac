# Multi-Environment Infrastructure Project

## Overview
This project implements a multi-environment infrastructure setup using Terraform and GitHub Actions.

## Environments
- **dev**: Development environment
- **test**: Testing/Staging environment  
- **prod**: Production environment

## Branching Strategy
- `dev` branch → Deploys to dev environment
- `test` branch → Deploys to test environment
- `main` branch → Deploys to prod environment

## Getting Started
1. Clone the repository
2. Checkout appropriate branch for your work
3. Make changes to terraform files
4. Push to trigger deployment

## Documentation
See `docs/` folder for detailed setup and deployment instructions.
