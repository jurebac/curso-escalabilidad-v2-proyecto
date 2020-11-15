provider "aws" { 
  region = "eu-west-3"
}

variable "server_port" { 
  description = "The port the server will use for HTTP requests" 
  type = number 
  default = 8080 
}

resource "aws_instance" "ec2-pinchito_01" {
  ami = "ami-0bd64587122fabdd5" 
  instance_type = "t2.micro" 
  vpc_security_group_ids = [aws_security_group.instance.id]
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello Mr. SRE, from AWS!!!!" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF


  tags = { 
    Name = "pinchito_01" 
  }
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress { 
    from_port = var.server_port 
    to_port = var.server_port
    protocol = "tcp" 
    cidr_blocks = [ "0.0.0.0/0" ] 
  }
}

output "public_ip" { 
  value = aws_instance.ec2-pinchito_01.public_dns
  description = "The public DNS name of the web server"
}

