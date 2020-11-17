#--------------------------------------------------------------------------------------------------
#
# Provider
#--------------------------------------------------------------------------------------------------

provider "aws" {
  region = "eu-west-3"
}

#--------------------------------------------------------------------------------------------------
#
# Variables
#--------------------------------------------------------------------------------------------------

variable "loadbalancer_port" {
  description = "Puerto del balanceador abierto"
  type = number
  default = 7017
}


variable "server_app_port" {
  description = "Puerto de la aplicación publicada en los servidores"
  type        = number
  default     = 3000
}


#--------------------------------------------------------------------------------------------------
#
# Datasources
#--------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}


#--------------------------------------------------------------------------------------------------
#
# DB Redis instance
#--------------------------------------------------------------------------------------------------
resource "aws_instance" "redis-db" {
  #Bitnami Redis AMI
  ami = "ami-09fbf6ab558b106ce"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg_redis.id]
  tags = {
    Name = "redis-db"
  }
}

resource "aws_security_group" "sg_redis" {
  name = "sg_redis"
  ingress {
    from_port = 6379
    to_port = 6379
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
   }
}


output "redis_ip" {
  value       = aws_instance.redis-db.private_ip
  description = "The domain name of the redis instance"
}



#--------------------------------------------------------------------------------------------------
#
# Auto Scaling Group (EC2 instances cluster)
#--------------------------------------------------------------------------------------------------

resource "aws_autoscaling_group" "asg1" {
  launch_configuration = aws_launch_configuration.lc1.name
  vpc_zone_identifier  = data.aws_subnet_ids.default.ids
  target_group_arns = [aws_lb_target_group.lb_tg1.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 3

  tag {
    key                 = "Name"
    value               = "asg1"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "lc1" {
  #Imagen pinchito-loadtest-2020-11-08
  image_id = "ami-0bd64587122fabdd5"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.asg_sg1.id]
  
  #Script con comandos para instalar aplicación
  user_data = file("install_app.sh")

  # Required when using a launch configuration with an auto scaling group.
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_security_group" "asg_sg1" {
  name = "asg_sg1"
  ingress {
    from_port   = var.server_app_port
    to_port     = var.server_app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #Permito acceso SSH a las instancias EC2 del Autoscaling group
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Habilito acceso hacia el exterior de las instancias, para la instalación de paquetes con npm
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#--------------------------------------------------------------------------
#
# Load Balancer
#--------------------------------------------------------------------------

resource "aws_lb" "lb1" {
  name               = "sre-app-lb"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default.ids
  security_groups    = [aws_security_group.lb_sg1.id]

}

resource "aws_lb_listener" "lb_list1" {
  load_balancer_arn = aws_lb.lb1.arn
  port              = var.loadbalancer_port
  protocol          = "HTTP"
  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_lb_listener_rule" "lb_lr1" {
  listener_arn = aws_lb_listener.lb_list1.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["/turno/*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_tg1.arn
  }
}

resource "aws_lb_target_group" "lb_tg1" {
  name     = "lb-tg1"
  port     = var.server_app_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_security_group" "lb_sg1" {
  name = "lb_sg1"

  # Allow inbound requests
  ingress {
    from_port   = var.loadbalancer_port
    to_port     = var.loadbalancer_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#--------------------------------------------------------------------------
#
# Output the load balancer DNS name
#--------------------------------------------------------------------------

output "alb_dns_name" {
  value       = aws_lb.lb1.dns_name
  description = "The domain name of the load balancer"
}

