provider "aws" {
  region = "eu-north-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "template_file" "user_data" {
  template = file("user-data.sh.tpl")
  vars = {
    db_url = aws_db_instance.default.address
  }
}

terraform {
  backend "s3" {
    bucket = "s3-petclinic-bucket"
    key    = "terraform-states/"
    region = "eu-north-1"
  }
}

########## VPC ########

resource "aws_vpc" "prod-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  tags = {
    Name = "prod-vpc"
  }
}

resource "aws_subnet" "prod-subnet-public-1" {
  vpc_id                  = aws_vpc.prod-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true" //it makes this a public subnet
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "prod-subnet-public-1"
  }
}

resource "aws_subnet" "prod-subnet-public-2" {
  vpc_id                  = aws_vpc.prod-vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = "true" //it makes this a public subnet
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "prod-subnet-public-2"
  }
}

resource "aws_subnet" "prod-subnet-private-1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "prod-subnet-private-1"
  }
}

resource "aws_subnet" "prod-subnet-private-2" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "prod-subnet-private-2"
  }
}

####### IG and NAT ########

resource "aws_internet_gateway" "prod-igw" {
  vpc_id = aws_vpc.prod-vpc.id
  tags = {
    Name = "pet-igw"
  }
}

resource "aws_eip" "nat_eip1" {
  vpc        = true
  depends_on = [aws_internet_gateway.prod-igw]
}

resource "aws_eip" "nat_eip2" {
  vpc        = true
  depends_on = [aws_internet_gateway.prod-igw]
}

resource "aws_nat_gateway" "nat1" {
  allocation_id = aws_eip.nat_eip1.id
  subnet_id     = aws_subnet.prod-subnet-private-1.id

  tags = {
    Name = "nat_private_1"
  }
}

resource "aws_nat_gateway" "nat2" {
  allocation_id = aws_eip.nat_eip2.id
  subnet_id     = aws_subnet.prod-subnet-private-2.id

  tags = {
    Name = "nat_private_2"
  }
}

######## Route table ########
resource "aws_route_table" "prod-public-crt" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    //associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"
    //CRT uses this IGW to reach internet
    gateway_id = aws_internet_gateway.prod-igw.id
  }

  tags = {
    Name = "prod-public-crt"
  }
}

resource "aws_route_table" "prod-private1-crt" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    //associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"
    //CRT uses this IGW to reach internet
    gateway_id = aws_nat_gateway.nat1.id
  }

  tags = {
    Name = "prod-private1-crt"
  }
}

resource "aws_route_table" "prod-private2-crt" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    //associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"
    //CRT uses this IGW to reach internet
    gateway_id = aws_nat_gateway.nat2.id
  }

  tags = {
    Name = "prod-private2-crt"
  }
}

resource "aws_route_table_association" "prod-crta-public-subnet-1" {
  subnet_id      = aws_subnet.prod-subnet-public-1.id
  route_table_id = aws_route_table.prod-public-crt.id
}

resource "aws_route_table_association" "prod-crta-public-subnet-2" {
  subnet_id      = aws_subnet.prod-subnet-public-2.id
  route_table_id = aws_route_table.prod-public-crt.id
}

resource "aws_route_table_association" "prod-crta-private-subnet-1" {
  subnet_id      = aws_subnet.prod-subnet-private-1.id
  route_table_id = aws_route_table.prod-private1-crt.id
}

resource "aws_route_table_association" "prod-crta-private-subnet-2" {
  subnet_id      = aws_subnet.prod-subnet-private-2.id
  route_table_id = aws_route_table.prod-private2-crt.id
}

############# security_group ##############

resource "aws_security_group" "security_group" {
  vpc_id = aws_vpc.prod-vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = ["8080", "22", "80"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = {
    Name = "security_group"
  }
}

############# EC2 #############

data "aws_ami" "ubuntu" {

  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "PC1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  key_name               = "pet-key"
  vpc_security_group_ids = [aws_security_group.security_group.id]
  depends_on             = [aws_db_instance.default]
  subnet_id              = aws_subnet.prod-subnet-public-1.id
  user_data              = data.template_file.user_data.rendered

  tags = {
    Name = "PC1"
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_instance" "PC2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  key_name               = "pet-key"
  vpc_security_group_ids = [aws_security_group.security_group.id]
  subnet_id              = aws_subnet.prod-subnet-public-2.id
  depends_on             = [aws_db_instance.default]
  user_data              = data.template_file.user_data.rendered

  tags = {
    Name = "PC2"
  }

  lifecycle {
    create_before_destroy = true
  }

}

############ RDS ###############

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "subnet-group"
  subnet_ids = [aws_subnet.prod-subnet-private-1.id, aws_subnet.prod-subnet-private-2.id]
}

resource "aws_security_group" "security_group_rds" {
  name   = "terraform_rds_security_group"
  vpc_id = aws_vpc.prod-vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "terraform-example-rds-security-group"
  }
}

resource "aws_db_instance" "default" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.small"
  db_name                = "petclinic"
  username               = "petclinic"
  password               = "petclinic"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.id
  vpc_security_group_ids = [aws_security_group.security_group_rds.id]
  skip_final_snapshot    = true
}

###### load_balancer ####

resource "aws_elb" "pet-elb" {
  name            = "pet-elb"
  subnets         = [aws_subnet.prod-subnet-public-1.id, aws_subnet.prod-subnet-public-2.id]
  security_groups = [aws_security_group.security_group.id]

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8080/"
    interval            = 300
  }

  instances                   = [aws_instance.PC1.id, aws_instance.PC2.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 100
  connection_draining         = true
  connection_draining_timeout = 300

  tags = {
    Name = "pet-elb"
  }
}

######## outputs ##########

output "elb-dns-name" {
  value = aws_elb.pet-elb.dns_name
}

output "rds_url" {
  value = aws_db_instance.default.address
}
