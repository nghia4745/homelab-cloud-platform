# S3 backend module
# Provisions an S3 bucket for remote state and a DynamoDB table for state locking.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  default_bucket_name = "${var.project_name}-${var.environment}-tfstate-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  default_table_name  = "${var.project_name}-${var.environment}-tfstate-lock"

  state_bucket_name    = var.bucket_name != "" ? var.bucket_name : local.default_bucket_name
  lock_table_name      = var.dynamodb_table_name != "" ? var.dynamodb_table_name : local.default_table_name
  dynamodb_kms_key_arn = var.dynamodb_kms_key_arn != "" ? var.dynamodb_kms_key_arn : aws_kms_key.dynamodb[0].arn

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "s3"
    Owner       = lookup(var.tags, "Owner", "unknown")
  })
}

resource "aws_kms_key" "dynamodb" {
  count = var.dynamodb_kms_key_arn == "" ? 1 : 0

  description             = "CMK for DynamoDB state lock table encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.lock_table_name}-cmk"
  })
}

resource "aws_kms_alias" "dynamodb" {
  count = var.dynamodb_kms_key_arn == "" ? 1 : 0

  name          = "alias/${local.lock_table_name}-cmk"
  target_key_id = aws_kms_key.dynamodb[0].key_id
}

resource "aws_s3_bucket" "state" {
  bucket        = lower(local.state_bucket_name)
  force_destroy = var.force_destroy

  tags = merge(local.common_tags, {
    Name = lower(local.state_bucket_name)
  })
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state_tls_only" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_tls_only.json
}

resource "aws_dynamodb_table" "lock" {
  name         = local.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.dynamodb_kms_key_arn
  }

  tags = merge(local.common_tags, {
    Name = local.lock_table_name
  })
}