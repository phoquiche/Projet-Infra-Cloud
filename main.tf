# ==========================================
# VPC Configuration
# ==========================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ==========================================
# S3 Bucket for Static Website
# ==========================================

resource "aws_s3_bucket" "website" {
  bucket = "${var.project_name}-website-${var.environment}"

  tags = {
    Name = "${var.project_name}-website"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.project_name}-s3-oac"
  description                       = "OAC for S3 website bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 Bucket Policy for CloudFront
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

# ==========================================
# CloudFront Distribution
# ==========================================

resource "aws_cloudfront_distribution" "s3_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.project_name}"
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.website.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project_name}-cloudfront"
  }
}

# ==========================================
# DynamoDB Tables
# ==========================================

resource "aws_dynamodb_table" "orders" {
  name         = "${var.project_name}-orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-orders"
  }
}

resource "aws_dynamodb_table" "payments" {
  name         = "${var.project_name}-payments"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "payment_id"

  attribute {
    name = "payment_id"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-payments"
  }
}

resource "aws_dynamodb_table" "inventory" {
  name         = "${var.project_name}-inventory"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "item_id"

  attribute {
    name = "item_id"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-inventory"
  }
}

# ==========================================
# IAM Roles and Policies for Lambda
# ==========================================

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-lambda-execution-role"
  }
}

# Attach AWS managed policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach AWS managed policy for VPC access
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Custom policy for DynamoDB access
resource "aws_iam_policy" "lambda_dynamodb" {
  name        = "${var.project_name}-lambda-dynamodb-policy"
  description = "Policy for Lambda to access DynamoDB tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.orders.arn,
          aws_dynamodb_table.payments.arn,
          aws_dynamodb_table.inventory.arn
        ]
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-lambda-dynamodb-policy"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_dynamodb.arn
}

# ==========================================
# Security Group for Lambda
# ==========================================

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-lambda-sg"
  }
}

# ==========================================
# Lambda Functions
# ==========================================

# Orders Lambda Function
resource "aws_lambda_function" "orders" {
  filename      = "${path.module}/lambda/orders.zip"
  function_name = "${var.project_name}-orders"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 30

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.orders.name
    }
  }

  tags = {
    Name = "${var.project_name}-orders-lambda"
  }
}

# Payments Lambda Function
resource "aws_lambda_function" "payments" {
  filename      = "${path.module}/lambda/payments.zip"
  function_name = "${var.project_name}-payments"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 30

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.payments.name
    }
  }

  tags = {
    Name = "${var.project_name}-payments-lambda"
  }
}

# Inventory Lambda Function
resource "aws_lambda_function" "inventory" {
  filename      = "${path.module}/lambda/inventory.zip"
  function_name = "${var.project_name}-inventory"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 30

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.inventory.name
    }
  }

  tags = {
    Name = "${var.project_name}-inventory-lambda"
  }
}

# ==========================================
# API Gateway
# ==========================================

resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "API Gateway for ${var.project_name}"

  tags = {
    Name = "${var.project_name}-api-gateway"
  }
}

# Orders API Resource
resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "orders"
}

resource "aws_api_gateway_method" "orders" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "orders" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.orders.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.orders.invoke_arn
}

# Payments API Resource
resource "aws_api_gateway_resource" "payments" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "payments"
}

resource "aws_api_gateway_method" "payments" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.payments.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "payments" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.payments.id
  http_method             = aws_api_gateway_method.payments.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.payments.invoke_arn
}

# Inventory API Resource
resource "aws_api_gateway_resource" "inventory" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "inventory"
}

resource "aws_api_gateway_method" "inventory" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.inventory.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "inventory" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.inventory.id
  http_method             = aws_api_gateway_method.inventory.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.inventory.invoke_arn
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  depends_on = [
    aws_api_gateway_integration.orders,
    aws_api_gateway_integration.payments,
    aws_api_gateway_integration.inventory
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  tags = {
    Name = "${var.project_name}-api-stage-${var.environment}"
  }
}

# Lambda Permissions for API Gateway
resource "aws_lambda_permission" "orders" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orders.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "payments" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.payments.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "inventory" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inventory.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}
