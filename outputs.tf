output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "cloudfront_distribution_domain" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for website"
  value       = aws_s3_bucket.website.id
}

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "dynamodb_tables" {
  description = "DynamoDB table names"
  value = {
    orders    = aws_dynamodb_table.orders.name
    payments  = aws_dynamodb_table.payments.name
    inventory = aws_dynamodb_table.inventory.name
  }
}

output "lambda_functions" {
  description = "Lambda function names"
  value = {
    orders    = aws_lambda_function.orders.function_name
    payments  = aws_lambda_function.payments.function_name
    inventory = aws_lambda_function.inventory.function_name
  }
}
