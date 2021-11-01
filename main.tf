provider "aws" {
  region = "eu-central-1"
}
resource "aws_instance" "ubuntu-vpc-2" {
 ami           = "ami-0a49b025fffbbdac6"
  instance_type = "t3.micro"
  
  tags = {
    Name = "ubuntu-vpc-2"
  }
  key_name = aws_key_pair.ed1.id
  iam_instance_profile = "AdminAccessFullEC2"
  subnet_id            = aws_subnet.publicsubnet.id
  vpc_security_group_ids = [aws_security_group.sec-grp-web.id]
  provisioner "local-exec"  {
  command = "sudo apt update -y; sudo apt install git -y; sudo apt install nginx -y; sudo git clone https://github.com/dmiryan/content-widget-factory-inc.git ~/tmp; sudo cp -r ~/tmp/web/. /var/www/html/"
}

}

resource "aws_vpc" "vpc-2" {                # Creating VPC here
   cidr_block       = "10.0.0.0/16"     # Defining the CIDR block use 10.0.0.0/24 for demo
   instance_tenancy = "default"
 }
 //Create Internet Gateway and attach it to VPC
 resource "aws_internet_gateway" "igw-2" {    # Creating Internet Gateway
    vpc_id =  aws_vpc.vpc-2.id               # vpc_id will be generated after we create VPC
 }
 //Create a Public Subnets.
 resource "aws_subnet" "publicsubnet" {    # Creating Public Subnets
   vpc_id =  aws_vpc.vpc-2.id
   cidr_block = "10.0.1.0/24"        # CIDR block of public subnets
   map_public_ip_on_launch = "true" //it makes this a public subnet
 }
 //Create a Private Subnet                   # Creating Private Subnets
 resource "aws_subnet" "privatesubnet" {
   vpc_id =  aws_vpc.vpc-2.id
   cidr_block = "10.0.11.0/24"          # CIDR block of private subnets
 }
 //Route table for Public Subnet's
 resource "aws_route_table" "PublicRT" {    # Creating RT for Public Subnet
    vpc_id =  aws_vpc.vpc-2.id
         route {
    cidr_block = "0.0.0.0/0"               # Traffic from Public Subnet reaches Internet via Internet Gateway
    gateway_id = aws_internet_gateway.igw-2.id
     }
 }
 //Route table for Private Subnet's
 resource "aws_route_table" "PrivateRT" {    # Creating RT for Private Subnet
   vpc_id = aws_vpc.vpc-2.id
   route {
   cidr_block = "0.0.0.0/0"             # Traffic from Private Subnet reaches Internet via NAT Gateway
   nat_gateway_id = aws_nat_gateway.NATgw-2.id
   }
 }
 //Route table Association with Public Subnet's
 resource "aws_route_table_association" "PublicRTassociation" {
    subnet_id = aws_subnet.publicsubnet.id
    route_table_id = aws_route_table.PublicRT.id
 }
 //Route table Association with Private Subnet's
 resource "aws_route_table_association" "PrivateRTassociation" {
    subnet_id = aws_subnet.privatesubnet.id
    route_table_id = aws_route_table.PrivateRT.id
 }
 resource "aws_eip" "nateIP" {
   vpc   = true
 }
 //Creating the NAT Gateway using subnet_id and allocation_id
 resource "aws_nat_gateway" "NATgw-2" {
   allocation_id = aws_eip.nateIP.id
   subnet_id = aws_subnet.publicsubnet.id
 }

# Create the Security Group
resource "aws_security_group" "sec-grp-web" {
  vpc_id       = aws_vpc.vpc-2.id
  name         = "ports 22 80"
  
  # allow ingress of port 22
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  } 
 # allow ingress of port 80
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }
  # allow egress of all ports
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_key_pair" "ed1" {
  key_name   = "ed1"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP12xI6YgHVc5r/rR5qWIzILPIdanVnL6Lx/qZ0pZPT1"

 }

resource "aws_lb" "alb-1" {
  name               = "alb-1"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sec-grp-web.id]
  subnets            = [aws_subnet.publicsubnet.id, aws_subnet.privatesubnet.id]
  enable_deletion_protection = true
}

resource "aws_lb_target_group" "tg-1_alb-1" {
  //name     = "tg-1_alb-1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc-2.id
}

resource "aws_lb_listener" "listener-1_alb-1" {
  load_balancer_arn = aws_lb.alb-1.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-1_alb-1.arn
  }
}

resource "aws_route53_zone" "mymir" {
  name = "mymir.xyz"
}

resource "aws_route53_record" "mymir" {
  zone_id = aws_route53_zone.mymir.zone_id
  name    = "mymir.xyz"
  type    = "A"

  alias {
    name                   = aws_lb.alb-1.dns_name
    zone_id                = aws_lb.alb-1.zone_id
    evaluate_target_health = true
  }
}

resource "aws_lb_target_group_attachment" "mymir" {
  target_group_arn = aws_lb_target_group.tg-1_alb-1.arn
  target_id        = aws_instance.ubuntu-vpc-2.id
  port             = 80
}
