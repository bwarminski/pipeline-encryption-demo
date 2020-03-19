resource "aws_redshift_cluster" "cluster" {
  cluster_identifier        = "demo-cluster"
  node_type                 = "dc2.large"
  cluster_type              = "single-node"
  master_password           = var.redshift_password
  master_username           = "dbadmin"
  vpc_security_group_ids    = [aws_security_group.redshift_group.id]
  cluster_subnet_group_name = aws_redshift_subnet_group.redshift-subnets.name
  skip_final_snapshot       = true
  iam_roles                 = [aws_iam_role.redshift-s3.arn]
}

resource "aws_iam_role" "redshift-s3" {
  name               = "redshift-s3"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "redshift.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  path               = "/"
}

resource "aws_iam_role_policy" "redshift-s3" {
  role   = aws_iam_role.redshift-s3.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}
