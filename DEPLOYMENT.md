# Projet Infrastructure Cloud - AWS Terraform

This project contains Terraform Infrastructure as Code (IaC) for deploying a complete AWS infrastructure including:
- VPC with public and private subnets
- S3 bucket for static website hosting
- CloudFront distribution for CDN
- DynamoDB tables for data management
- Lambda functions for business logic
- API Gateway for REST API endpoints

## Architecture Overview

### Components

1. **VPC Infrastructure**
   - Custom VPC with configurable CIDR block
   - Public subnets (2) for internet-facing resources
   - Private subnets (2) for Lambda functions
   - Internet Gateway for public access
   - Route tables for proper traffic routing

2. **Static Website Hosting**
   - S3 bucket for hosting static website files
   - CloudFront distribution with Origin Access Control (OAC)
   - HTTPS redirection enabled
   - Versioning enabled for website bucket

3. **Serverless API Backend**
   - Three Lambda functions:
     - Orders management
     - Payments processing
     - Inventory management
   - Lambda functions deployed in private subnets
   - IAM roles with least privilege access

4. **Data Storage**
   - Three DynamoDB tables (pay-per-request billing):
     - Orders table (hash key: order_id)
     - Payments table (hash key: payment_id)
     - Inventory table (hash key: item_id)

5. **API Gateway**
   - REST API with three endpoints:
     - `/orders` - Order management
     - `/payments` - Payment processing
     - `/inventory` - Inventory management
   - Integrated with Lambda functions via AWS_PROXY integration

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- AWS CLI configured with credentials

## Directory Structure

```
.
├── provider.tf          # Terraform provider configuration
├── variables.tf         # Input variables
├── main.tf             # Main infrastructure resources
├── outputs.tf          # Output values
├── lambda/             # Lambda function code
│   ├── orders/         # Orders Lambda function
│   │   ├── index.js
│   │   └── package.json
│   ├── payments/       # Payments Lambda function
│   │   ├── index.js
│   │   └── package.json
│   └── inventory/      # Inventory Lambda function
│       ├── index.js
│       └── package.json
└── README.md
```

## Configuration Variables

You can customize the deployment by modifying the variables in `variables.tf` or by creating a `terraform.tfvars` file:

```hcl
aws_region           = "us-east-1"
environment          = "dev"
project_name         = "projet-infra-cloud"
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]
```

## Deployment Instructions

### 1. Initialize Terraform

```bash
terraform init
```

This will download the required AWS provider plugins.

### 2. Review the Plan

```bash
terraform plan
```

Review the resources that will be created.

### 3. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm the deployment.

### 4. Retrieve Output Values

After successful deployment, Terraform will output important values:

```bash
terraform output
```

Key outputs include:
- CloudFront distribution domain name
- API Gateway URL
- VPC ID
- DynamoDB table names
- Lambda function names

## Uploading Website Content

After deployment, you need to upload your website files to the S3 bucket:

```bash
# Get the bucket name from Terraform output
BUCKET_NAME=$(terraform output -raw s3_bucket_name)

# Upload your website files
aws s3 sync ./website s3://$BUCKET_NAME/

# Example: Upload a simple index.html
echo "<html><body><h1>Welcome to Projet Infra Cloud</h1></body></html>" > index.html
aws s3 cp index.html s3://$BUCKET_NAME/index.html
```

The website will be accessible via the CloudFront distribution URL.

## API Usage Examples

### Orders API

```bash
# Get API Gateway URL
API_URL=$(terraform output -raw api_gateway_url)

# Create an order
curl -X POST $API_URL/orders \
  -H "Content-Type: application/json" \
  -d '{"customer_name": "John Doe", "items": ["item1", "item2"], "total": 99.99}'

# List all orders
curl $API_URL/orders

# Get a specific order
curl $API_URL/orders/{order_id}

# Update an order
curl -X PUT $API_URL/orders/{order_id} \
  -H "Content-Type: application/json" \
  -d '{"status": "completed"}'

# Delete an order
curl -X DELETE $API_URL/orders/{order_id}
```

### Payments API

```bash
# Create a payment
curl -X POST $API_URL/payments \
  -H "Content-Type: application/json" \
  -d '{"order_id": "order-123", "amount": 99.99, "method": "credit_card"}'

# List all payments
curl $API_URL/payments
```

### Inventory API

```bash
# Create an inventory item
curl -X POST $API_URL/inventory \
  -H "Content-Type: application/json" \
  -d '{"name": "Product A", "quantity": 100, "price": 29.99}'

# List all inventory items
curl $API_URL/inventory

# Update inventory
curl -X PUT $API_URL/inventory/{item_id} \
  -H "Content-Type: application/json" \
  -d '{"quantity": 95}'
```

## Lambda Function Development

The Lambda functions are written in Node.js and use the AWS SDK v3 for DynamoDB operations.

To update Lambda functions:

1. Modify the code in `lambda/{function}/index.js`
2. Recreate the zip file:
   ```bash
   cd lambda/{function}
   zip -r ../{function}.zip index.js package.json
   ```
3. Run `terraform apply` to update the Lambda function

For production deployments, consider:
- Installing dependencies: `npm install` before creating the zip
- Using a CI/CD pipeline for automated deployments
- Implementing proper error handling and logging
- Adding unit tests for Lambda functions

## Security Considerations

- Lambda functions are deployed in private subnets
- S3 bucket has public access blocked
- CloudFront uses Origin Access Control (OAC) for secure S3 access
- IAM roles follow least privilege principle
- All resources are tagged for tracking
- HTTPS is enforced on CloudFront

## Monitoring and Logs

- Lambda logs are available in CloudWatch Logs
- API Gateway logs can be enabled via additional configuration
- CloudFront access logs can be configured
- DynamoDB metrics are available in CloudWatch

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Type `yes` when prompted to confirm deletion.

**Note**: Ensure the S3 bucket is empty before destroying, or the deletion may fail.

## Cost Considerations

- VPC: No charge for VPC, subnets, route tables
- NAT Gateway: Not included (can be added for private subnet internet access)
- S3: Pay for storage and data transfer
- CloudFront: Pay for data transfer out
- Lambda: Pay per request and execution time
- DynamoDB: Pay per request (on-demand billing mode)
- API Gateway: Pay per request

Most services in this setup are eligible for AWS Free Tier.

## Customization

### Adding More Lambda Functions

1. Create a new directory in `lambda/`
2. Add Lambda function code and package.json
3. Create a zip file
4. Add Lambda resource in `main.tf`
5. Add API Gateway integration

### Changing Region

Update the `aws_region` variable and ensure the availability zones match the chosen region.

### Adding Authentication

Consider adding:
- API Gateway API Keys
- AWS Cognito for user authentication
- Lambda authorizers for custom authentication

## Troubleshooting

### Lambda Functions in VPC

Lambda functions in VPC need:
- NAT Gateway or VPC endpoints for internet access
- Sufficient IP addresses in subnets
- Proper security group rules

### CloudFront Deployment

- CloudFront distributions take 15-20 minutes to deploy
- Cache invalidation may be needed after S3 updates

### DynamoDB Access

- Verify IAM permissions for Lambda execution role
- Check Lambda environment variables for correct table names

## Support

For issues or questions, please refer to:
- AWS Documentation: https://docs.aws.amazon.com/
- Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/

## License

This project is for educational purposes as part of the IMT Nord Europe cloud infrastructure project.
