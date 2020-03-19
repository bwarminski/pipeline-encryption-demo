resource "aws_security_group" "redshift_access" {
  name        = "redshift-access"
  description = "Allows Access to Redshift"
  vpc_id      = data.aws_vpc.selected.id
}

resource "aws_security_group_rule" "allow_all" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.redshift_access.id
}

resource "aws_security_group" "redshift_group" {
  name        = "redshift"
  description = "Redshift Base Group"
  vpc_id      = data.aws_vpc.selected.id
}

resource "aws_security_group_rule" "local-access" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 5439
  to_port           = 5439
  cidr_blocks       = ["${chomp(data.http.my_ip.body)}/32", "0.0.0.0/0"]
  security_group_id = aws_security_group.redshift_group.id
}

resource "aws_security_group_rule" "authorized-access" {
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 5439
  to_port                  = 5439
  source_security_group_id = aws_security_group.redshift_access.id
  security_group_id        = aws_security_group.redshift_group.id
}

resource "aws_redshift_subnet_group" "redshift-subnets" {
  name       = "redshift-subnets"
  subnet_ids = var.redshift_subnets
}

resource "aws_subnet" "lambda-subnet" {
  vpc_id            = data.aws_vpc.selected.id
  availability_zone = var.lamdba_az
  cidr_block        = var.lambda_subnet_cidr
}

resource "aws_eip" "nat-ip" {
  vpc = true
}

resource "aws_nat_gateway" "lambda-gateway" {
  allocation_id = aws_eip.nat-ip.id
  subnet_id     = var.nat_subnet
}

resource "aws_route_table" "lambda-private" {
  vpc_id = data.aws_vpc.selected.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.lambda-gateway.id
  }
}

resource "aws_route_table_association" "lambda-private" {
  subnet_id      = aws_subnet.lambda-subnet.id
  route_table_id = aws_route_table.lambda-private.id
}