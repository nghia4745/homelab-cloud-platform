# This file is intentionally insecure for testing purposes
resource "aws_s3_bucket" "test_bucket" {
  bucket = "my-insecure-data-bucket-2026"
  # MISTAKE 1: No encryption defined
  # MISTAKE 2: No public access block
}

resource "aws_security_group" "open_access" {
  name        = "allow_all"
  description = "Allow all inbound traffic"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    # MISTAKE 3: Opening port 0-65535 to the entire internet
    cidr_blocks = ["0.0.0.0/0"]
  }
}