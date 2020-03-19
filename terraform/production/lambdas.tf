resource "aws_iam_role" "generate-lambda" {
  name               = "generate-lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  path               = "/"
}

resource "aws_iam_role_policy" "generate-policy" {
  role   = aws_iam_role.generate-lambda.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:Put*",
                "s3:List*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },

        {
            "Effect": "Allow",
            "Action": "redshift:GetClusterCredentials",
            "Resource": [
              "arn:aws:redshift:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbname:${aws_redshift_cluster.cluster.cluster_identifier}/dev",
              "arn:aws:redshift:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_redshift_cluster.cluster.cluster_identifier}/loader"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DetachNetworkInterface",
                "ec2:DeleteNetworkInterface"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}
resource "aws_iam_role" "load-lambda" {
  name               = "load-lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  path               = "/"
}

resource "aws_iam_role_policy" "load-policy" {
  role   = aws_iam_role.load-lambda.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:Put*",
                "s3:List*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": "redshift:GetClusterCredentials",
            "Resource": [
              "arn:aws:redshift:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbname:${aws_redshift_cluster.cluster.cluster_identifier}/dev",
              "arn:aws:redshift:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_redshift_cluster.cluster.cluster_identifier}/loader"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DetachNetworkInterface",
                "ec2:DeleteNetworkInterface"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "sqs:GetQueueAttributes"
            ],
            "Resource": "${aws_sqs_queue.ingest-files.arn}"
        }
    ]
}
EOF
}
