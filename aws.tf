# --------------------------------------------------------
# AWS resources - learning examples
# --------------------------------------------------------
# Contains intentionally insecure configurations for educational
# purposes to demonstrate common security mistakes.
# WARNING: Do NOT use these configurations in production!
# --------------------------------------------------------

## TODO: uncomment when ready to use AWS!

# S3 Bucket - intentionally misconfigured for learning
# This file is intentionally insecure for testing purposes, to be removed later
# resource "aws_s3_bucket" "test_bucket" {
#   bucket = "my-secure-data-bucket-2026"
# }

# -------------------------------------------------------
# S3 Security Configuration - Encryption
# -------------------------------------------------------
# Enables server-side encryption on the S3 bucket
# AES256 is AWS-managed encryption (not KMS)
# This prevents unencrypted data from being stored
# -------------------------------------------------------
# resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
#   bucket = aws_s3_bucket.test_bucket.id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# -------------------------------------------------------
# S3 Security Configuration - Public Access Block
# -------------------------------------------------------
# Blocks all public access to the S3 bucket
# - block_public_acls: prevents public ACLs from being set
# - block_public_policy: prevents public bucket policies
# - ignore_public_acls: ignores existing public ACLs
# - restrict_public_buckets: restricts bucket policy effects
# -------------------------------------------------------
# resource "aws_s3_bucket_public_access_block" "example" {
#   bucket                  = aws_s3_bucket.test_bucket.id
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# -------------------------------------------------------
# Security Group - Restricted Access
# -------------------------------------------------------
# Restricts network traffic to only allow HTTP (port 80)
# Allows all outbound traffic (egress)
#
# Ingress rules:
# - Allow HTTP (port 80) from anywhere (0.0.0.0/0)
#
# Egress rules:
# - Allow all traffic outbound (protocol "-1" means all)
# -------------------------------------------------------
# resource "aws_security_group" "restricted_access" {
#   name        = "allow_web_only"
#   description = "Allow only web traffic"

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }
