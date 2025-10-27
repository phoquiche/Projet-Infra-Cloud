# Projet-Infra-Cloud
Projet d'infrastructure cloud IMT NORD EUROPE

## Overview

This repository contains Infrastructure as Code (IaC) using Terraform to deploy a complete AWS cloud infrastructure including:

- **VPC** with public and private subnets
- **S3 + CloudFront** for static website hosting
- **Lambda Functions** for serverless compute
- **API Gateway** for REST API endpoints
- **DynamoDB** for data persistence

## Quick Start

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions.

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy infrastructure
terraform apply
```

## Architecture

- **Frontend**: CloudFront → S3 (Static Website)
- **Backend**: API Gateway → Lambda Functions → DynamoDB
- **Network**: VPC with public/private subnets
- **APIs**: Orders, Payments, and Inventory management

## Documentation

- [Deployment Guide](DEPLOYMENT.md) - Complete deployment instructions
- [Variables](variables.tf) - Configuration options
- [Outputs](outputs.tf) - Infrastructure outputs

## Project Structure

```
.
├── provider.tf          # AWS provider configuration
├── variables.tf         # Input variables
├── main.tf             # Main infrastructure
├── outputs.tf          # Output values
├── lambda/             # Lambda functions
│   ├── orders/
│   ├── payments/
│   └── inventory/
└── DEPLOYMENT.md       # Detailed documentation
```
