####### variables 

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {}
variable "aws_key_pair" {}
variable "region" {
 default = "us-east-1"
}

variable "network_address_space" {
 default = "10.1.0.0/16"
}

variable "subnet1_address_space" {
 default = "10.1.0.0/24"
}

####### providers
provider "aws" {
 access_key = var.aws_access_key
 secret_key = var.aws_secret_key
 region = var.region
}
####### data 

# get the aws availability  zones
data "aws_availability_zones" "available" {}

# get the latest amis

data "aws_ami" "aws-linux" {
 most_recent = true
 owners = ["amazon"]
 
 filter {
  name = "name"
  values = ["amzn-ami-hvm*"]
 }
 
 filter {
  name = "root-device-type"
  values = ["ebs"]
 }
 
 filter {
  name = "virtualization-type"
  values = ["hvm"]
 }
}

#######  resources

# build the network
# set the address space and enable dns hostnames true.

resource "aws_vpc" "vpc" {
 cidr_block = var.network_address_space
 enable_dns_hostnames = "true"
}

# create an internet gateway and assign it to the vpc created above
resource "aws_internet_gateway" "igw"{
 vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "public_subnet1" {
 cidr_block = var.subnet1_address_space
 vpc_id = aws_vpc.vpc.id
 map_public_ip_on_launch = "true"
 availability_zone = data.aws_availability_zones.available.names[0]
}

######## routes

# set the route with defaul any ip to have internet gateway as the destination

resource "aws_route_table" "rtb" {
 vpc_id = aws_vpc.vpc.id
 
 route {
  cidr_block = "0.0.0.0/0"
  gateway_id  = aws_internet_gateway.igw.id
 }
}

resource "aws_route_table_association" "rta-subnet1" {
 subnet_id = aws_subnet.public_subnet1.id
 route_table_id = aws_route_table.rtb.id
}

###### security groups 

# set the nginx security group

resource "aws_security_group" "nginx-sg"{
 name = "nginx_sg"
 vpc_id = aws_vpc.vpc.id
 
 # ssh access from anywhere
 ingress {
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }
 
 # HTTP access from anywhere
 ingress{
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  }

 # outbound access
 egress {
  from_port = 0
  to_port = 0
  protocol = -1
  cidr_blocks = ["0.0.0.0/0"]
  }
 
 tags = {
  Name = "Nginx access rules"
 }
}
######## build the ec2 instances

resource "tls_private_key" "tlskey" {
 algorithm = "RSA"
 rsa_bits = 4096
}
# removed dollar sign for variables
resource "aws_key_pair" "generated_key" {
 key_name = var.key_name
 public_key = tls_private_key.tlskey.public_key_openssh

}

resource "aws_instance" "nginx1" {
 ami = data.aws_ami.aws-linux.id
 instance_type = "t2.micro"
 subnet_id = aws_subnet.public_subnet1.id
 vpc_security_group_ids = [aws_security_group.nginx-sg.id]
 key_name = var.aws_key_pair.generated_key.key_name

 connection {
  type = "ssh"
  host = self.public_ip
  user = "ec2-user"
  private_key = file(var.private_key_path)
 }
  
 provisioner "remote-exec" {
  inline = [
    "sudo yum install nginx -y",
    "sudo service nginx start",
    "echo '<html><head><title> Blue Team Server </title></head><body style=\"background-color: #1F778D\"> \"Hello this is bluei\" </body></html>' > /var/www/index.html"
   ]
 }
}
####OUTPUT

output "aws_instance_public_dns" {
 value = aws_instance.nginx1.public_dns
}

   


