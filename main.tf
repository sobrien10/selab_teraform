#Configure the AWS provider
provider "aws" {
  version = "~> 2.0"  
  region  = "eu-west-2"
}

#Configure the VPC and Public Subnets
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> v2.0"

  name = "${var.prefix}-f5-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-2a"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway = false

  tags = {
    Environment = "ob1-vpc-teraform"
  }
}

#Configure the security Group
resource "aws_security_group" "f5" {
  name   = "${var.prefix}-f5"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["90.208.9.18/32"]
  }

    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["90.208.9.18/32"]
  }

    ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["90.208.9.18/32"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["90.208.9.18/32"]
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["90.208.9.18/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ob1-SecurityGroup1"
  }
}

resource "aws_network_interface" "mgmt" {
  subnet_id   = module.vpc.public_subnets[0]
  private_ips = ["10.0.1.10"]
  security_groups = [ aws_security_group.f5.id ]

  tags = {
    Name = "mgmt_interface"
  }
}

resource "aws_eip" "mgmt" {
  vpc                       = true
  network_interface         = aws_network_interface.mgmt.id
  associate_with_private_ip = "10.0.1.10"
}

resource "aws_network_interface" "public" {
  subnet_id   = module.vpc.public_subnets[1]
  private_ips = ["10.0.2.10", "10.0.2.11"]
  security_groups = [ aws_security_group.f5.id ]

  tags = {
    Name = "public_interface"
  }
}

resource "aws_eip" "public1" {
  vpc                       = true
  network_interface         = aws_network_interface.public.id
  associate_with_private_ip = "10.0.2.10"
}

resource "aws_eip" "public2" {
  vpc                       = true
  network_interface         = aws_network_interface.public.id
  associate_with_private_ip = "10.0.2.11"
}

#Create the BIG-IP
resource "aws_instance" "big-ip" {
  ami           = "ami-0fe284d68b7936ab6"
  instance_type = "m5.xlarge"
  key_name      = "OB1-key-sews"

    network_interface {
    network_interface_id = aws_network_interface.mgmt.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.public.id
    device_index         = 1
  }

  tags = {
    Name = "ob1-mybigip"
  }
}