# ------------------------------------------------------------------------------
# Networking (VPC, Subnets, Gateways, Route Tables, and Security Groups)
# ------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                     = "${var.cluster_name}-vpc"
    "karpenter.sh/discovery" = var.cluster_name
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.cluster_name}-public-a"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.cluster_name}-public-b"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false

  tags = {
    Name                              = "${var.cluster_name}-private-a"
    "karpenter.sh/discovery"         = var.cluster_name
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.12.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = false

  tags = {
    Name                              = "${var.cluster_name}-private-b"
    "karpenter.sh/discovery"         = var.cluster_name
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat_a" {
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-a"
  }
}

resource "aws_eip" "nat_b" {
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-b"
  }
}

resource "aws_nat_gateway" "a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "${var.cluster_name}-nat-a"
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id

  tags = {
    Name = "${var.cluster_name}-nat-b"
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.a.id
  }

  tags = {
    Name = "${var.cluster_name}-private-a-rt"
  }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.b.id
  }

  tags = {
    Name = "${var.cluster_name}-private-b-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes"
  description = "Security group for EKS and Karpenter nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Node to node traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Node egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                     = "${var.cluster_name}-nodes"
    "karpenter.sh/discovery" = var.cluster_name
  }
}

resource "aws_security_group_rule" "nodes_from_cluster" {
  type                     = "ingress"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  description              = "EKS control plane to node kubelets"
}

resource "aws_security_group_rule" "cluster_from_nodes" {
  type                     = "ingress"
  security_group_id        = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.nodes.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "Nodes to EKS API server"
}
