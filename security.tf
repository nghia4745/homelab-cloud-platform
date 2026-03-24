# This is ONLY for flagging vulnerability for checkov, to be removed later before applying change to AWS
# resource "aws_security_group" "open_access" {
#   name        = "allow_all"
#   description = "Allow all inbound traffic"

#   ingress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     # MISTAKE 3: Opening port 0-65535 to the entire internet
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }