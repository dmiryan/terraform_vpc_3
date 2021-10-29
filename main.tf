provider "aws" {
  region = "eu-central-1"
}
resource "aws_instance" "ubuntu-vpc-2" {
 ami           = "ami-0a49b025fffbbdac6"
  instance_type = "t3.micro"
  tags = {
    Name = "ubuntu-vpc-2"
  }
  iam_instance_profile = "AdminAccessFullEC2"
  subnet_id            = aws_subnet.publicsubnet.id
  provisioner "local-exec"  {
  command = "apt update && apt install -y git && git clone https://github.com/dmiryan/content-widget-factory-inc.git"
      
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



