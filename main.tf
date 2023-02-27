
#########################################################################################################
#########################################################################################################
#################################### PROVISION HA WEB APPLICATION (AWS) #################################
#########################################################################################################
#########################################################################################################


# 1. Networking Infrastucture
# 2. Security Infrastructure
# 3. Compute Infrastructure


#########################################################################################################
####################################### NETWORKING INFRASTRUCTURE #######################################
#########################################################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "HA_WebApp_TF" {                
   cidr_block       = var.main_vpc_cidr
   instance_tenancy = "default"
   tags = {
     "Name" = "HA_WebApp_VPC_TF"
   }
}

resource "aws_internet_gateway" "IGW" {    
    vpc_id =  aws_vpc.HA_WebApp_TF.id
}

resource "aws_subnet" "HA_WebApp_Public_1" {
   vpc_id =  aws_vpc.HA_WebApp_TF.id # Required ID of VPC to be created within
   cidr_block = "${var.public_subnet1}"        # CIDR block of public subnets
   availability_zone = data.aws_availability_zones.available.names[0]
   tags = {
     "Name" = "HA_WebApp_Public_1_TF"
   }
}

resource "aws_subnet" "HA_WebApp_Public_2" {
   vpc_id =  aws_vpc.HA_WebApp_TF.id # Required ID of VPC to be created within
   cidr_block = "${var.public_subnet2}"        # CIDR block of public subnets
   availability_zone = data.aws_availability_zones.available.names[1]
   tags = {
     "Name" = "HA_WebApp_Public_2_TF"
   }
}

resource "aws_subnet" "HA_WebApp_Private_1" {
   vpc_id =  aws_vpc.HA_WebApp_TF.id # Required ID of VPC to be created within
   cidr_block = "${var.private_subnet1}"        # CIDR block of public subnets
   availability_zone = data.aws_availability_zones.available.names[0]
   tags = {
     "Name" = "HA_WebApp_Private_1_TF"
   }
}

resource "aws_subnet" "HA_WebApp_Private_2" {
   vpc_id =  aws_vpc.HA_WebApp_TF.id # Required ID of VPC to be created within
   cidr_block = "${var.private_subnet2}"        # CIDR block of public subnets
   availability_zone = data.aws_availability_zones.available.names[1]
   tags = {
     "Name" = "HA_WebApp_Private_2_TF"
   }
}

resource "aws_route_table" "PublicRT" {    # Creating RT for Public Subnet
    vpc_id =  aws_vpc.HA_WebApp_TF.id
        route {
    cidr_block = "0.0.0.0/0"               # Traffic from Public Subnet reaches Internet via Internet Gateway
    gateway_id = aws_internet_gateway.IGW.id
    }
    tags = {
     "Name" = "HA_WebApp_PublicRT_TF"
    }
}

resource "aws_route_table" "PrivateRT" {    # Creating RT for Private Subnet
   vpc_id = aws_vpc.HA_WebApp_TF.id
   route {
   cidr_block = "0.0.0.0/0"             # Traffic from Private Subnet reaches Internet via NAT Gateway
   nat_gateway_id = aws_nat_gateway.NATgw.id
   }
   tags = {
     "Name" = "HA_WebApp_PrivateRT_TF"
    }
}

resource "aws_route_table_association" "PublicRTassociation" {
    subnet_id = aws_subnet.HA_WebApp_Public_1.id
    route_table_id = aws_route_table.PublicRT.id
}

resource "aws_route_table_association" "PublicRTassociation2" {
    subnet_id = aws_subnet.HA_WebApp_Public_2.id
    route_table_id = aws_route_table.PublicRT.id
}
 
resource "aws_route_table_association" "PrivateRTassociation" {
    subnet_id = aws_subnet.HA_WebApp_Private_1.id
    route_table_id = aws_route_table.PrivateRT.id
}

resource "aws_route_table_association" "PrivateRTassociation2" {
    subnet_id = aws_subnet.HA_WebApp_Private_2.id
    route_table_id = aws_route_table.PrivateRT.id
}

resource "aws_eip" "nateIP" {
   vpc   = true
}

resource "aws_nat_gateway" "NATgw" {
   allocation_id = aws_eip.nateIP.id
   subnet_id = aws_subnet.HA_WebApp_Private_1.id
}

#########################################################################################################
######################################### SECURITY INFRASTRUCTURE #######################################
#########################################################################################################

resource "aws_security_group" "HA_WebApp_HTTP_SG_TF" {
  name = "Allow HTTP"
  description = "Allow HTTP inbound traffic"
  vpc_id = aws_vpc.HA_WebApp_TF.id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AllOW_HTTP_TF"
  }
}

resource "aws_security_group" "HA_WebApp_DB_SG_TF" {
  name = "Allow PostgreSQL access from LAN"
  description = "Allow incoming PostgreSQL access from LAN"
  vpc_id = aws_vpc.HA_WebApp_TF.id

  ingress {
    description      = "HTTP"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = var.main_vpc_cidr_list
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow PostgreSQL Inbound Access from LAN"
  }
}

#########################################################################################################
######################################### COMPUTE INFRASTRUCTURE ########################################
#########################################################################################################

resource "aws_instance" "HA_WebApp_LB_TF" {
  associate_public_ip_address = true
  ami           = "ami-0dfcb1ef8550277af"
  key_name = "MylesNewKey"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.HA_WebApp_Public_1.id
  vpc_security_group_ids = [aws_security_group.HA_WebApp_HTTP_SG_TF.id]
  tags = {
    Name = "HA_WebApp_LB_TF"
  }
  user_data = <<EOF
    #!/bin/bash
    hostname "HA-WebApp-LB-TF"
    OS_TYPE=$(cat /etc/os-release | awk -F'=' '/^NAME/ {print $2}'| tr -t '"' ' ' | xargs)
    export DD_API_KEY="${var.datadog_apikey}"
    export DD_SITE="us5.datadoghq.com"
    if [[ $OS_TYPE == "Amazon Linux" ]]
    then
        bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"
    elif [[ $OS_TYPE == "Red Hat Enterprise Linux" ]]
    then
        bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"
    fi
	EOF
}

resource "aws_instance" "HA_WebApp_DB_TF" {
  associate_public_ip_address = true    
  ami           = "ami-0dfcb1ef8550277af"
  key_name = "MylesNewKey"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.HA_WebApp_Private_1.id
  vpc_security_group_ids = [aws_security_group.HA_WebApp_DB_SG_TF.id]
  tags = {
    Name = "HA_WebApp_DB_TF"
  }
  user_data = <<EOF
    #!/bin/bash
    hostname "HA-WebApp-DB-TF"
    OS_TYPE=$(cat /etc/os-release | awk -F'=' '/^NAME/ {print $2}'| tr -t '"' ' ' | xargs)
    export DD_API_KEY="${var.datadog_apikey}"
    export DD_SITE="us5.datadoghq.com"
    if [[ $OS_TYPE == "Amazon Linux" ]]
    then
        bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"
    elif [[ $OS_TYPE == "Red Hat Enterprise Linux" ]]
    then
        bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"
    fi
	EOF
}

resource "aws_instance" "HA_WebApp_App1_TF" {
  associate_public_ip_address = true
  ami           = "ami-0dfcb1ef8550277af"
  key_name = "MylesNewKey"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.HA_WebApp_Public_1.id
  vpc_security_group_ids = [aws_security_group.HA_WebApp_HTTP_SG_TF.id]
  tags = {
    Name = "HA_WebApp_App1_TF"
  }
  user_data = <<EOF
    #!/bin/bash
    hostname "HA-WebApp-App1-TF"
    OS_TYPE=$(cat /etc/os-release | awk -F'=' '/^NAME/ {print $2}'| tr -t '"' ' ' | xargs)
    export DD_API_KEY="${var.datadog_apikey}"
    export DD_SITE="us5.datadoghq.com"
    if [[ $OS_TYPE == "Amazon Linux" ]]
    then
        bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"
    elif [[ $OS_TYPE == "Red Hat Enterprise Linux" ]]
    then
        bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"
    fi
	EOF
}

resource "aws_instance" "HA_WebApp_App2_TF" {
  associate_public_ip_address = true
  ami           = "ami-0dfcb1ef8550277af"
  key_name = "MylesNewKey"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.HA_WebApp_Public_2.id
  vpc_security_group_ids = [aws_security_group.HA_WebApp_HTTP_SG_TF.id]
  tags = {
    Name = "HA_WebApp_App2_TF"
  }
  user_data = <<EOF
    #!/bin/bash
    hostname "HA-WebApp-App2-TF"
    OS_TYPE=$(cat /etc/os-release | awk -F'=' '/^NAME/ {print $2}'| tr -t '"' ' ' | xargs)
    export DD_API_KEY="${var.datadog_apikey}"
    export DD_SITE="us5.datadoghq.com"
    if [[ $OS_TYPE == "Amazon Linux" ]]
    then
        bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"
    elif [[ $OS_TYPE == "Red Hat Enterprise Linux" ]]
    then
        bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script_agent7.sh)"
    fi
	EOF
}

