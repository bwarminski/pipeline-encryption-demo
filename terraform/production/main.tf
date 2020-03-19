provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "redshift_password" {
  type = string
}

variable "vpc_id" {
  type    = string
  default = null
}

variable "redshift_subnets" {
  type = list(string)
}

variable "lamdba_az" {
  type = string
}

variable "lambda_subnet_cidr" {
  type = string
}

variable "nat_subnet" {
  type = string
}

data "aws_vpc" "selected" {
  id      = var.vpc_id
  default = var.vpc_id == null ? true : false
}

data "http" "my_ip" { // Don't like this, but let's keep it pure
  url = "http://ipv4.icanhazip.com"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "ingest" {
  bucket        = "bwarminski.redshift.ingest"
  force_destroy = true
}

resource "aws_sqs_queue" "ingest-files" {
  name                       = "new-redshift-files"
  visibility_timeout_seconds = 60 // Match Lambda Timeout
}

resource "aws_sqs_queue_policy" "allow-s3-sqs" {
  queue_url = aws_sqs_queue.ingest-files.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.ingest-files.arn}",
      "Condition": {
         "ArnLike": { "aws:SourceArn": "${aws_s3_bucket.ingest.arn}" }
      }
    }
  ]
}
POLICY
}

resource "aws_s3_bucket_notification" "bucket-notification" {
  bucket = aws_s3_bucket.ingest.id

  queue {
    queue_arn     = aws_sqs_queue.ingest-files.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".json.gz"
  }
}



output "lambda-security-group" {
  value = aws_security_group.redshift_access.id
}

output "lambda-subnet-id" {
  value = aws_subnet.lambda-subnet.id
}