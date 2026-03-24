# This file is intentionally insecure for testing purposes, to be removed later
resource "aws_s3_bucket" "test_bucket" {
  bucket = "my-insecure-data-bucket-2026"
  # MISTAKE 1: No encryption defined
  # MISTAKE 2: No public access block
}