provider "aws" { 
  region = "eu-west-3"
}

resource "aws_instance" "tf-test" { 
  ami = "ami-0bd64587122fabdd5" 
  instance_type = "t2.micro" 

  tags = { 
    Name = "pinchito_01" 
  }
}
