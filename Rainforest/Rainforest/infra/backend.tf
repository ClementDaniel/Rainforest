# S3 bucket for state storage and DynamoDB for state locking

terraform {
  backend "s3" {
    bucket       = "rainforest-tfstate"
    key          = "terraform-api.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
    acl          = "private"
  }
}
resource "aws_dynamodb_table" "terraform_locks" {
  count        = var.create_lock_table ? 1 : 0
  name         = "rainforest-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.common_tags
}
