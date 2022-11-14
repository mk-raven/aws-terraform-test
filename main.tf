terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}



resource "aws_launch_template" "web" {
  name = "web"
  image_id        = "ami-0fd8802f94ed1c969"
  instance_type   = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_web.id]
  network_interfaces {
    associate_public_ip_address = true
  }

  placement {
    availability_zone = "eu-west-1"
  }
  
  user_data = filebase64("${path.module}/bootstrap.sh")
  
  lifecycle {
    create_before_destroy = true
  }

    tags = {
      Name = "web"
    }
}

resource "aws_lb_target_group" "web" {
  name     = "web"
  port     = 80
  protocol = "HTTP"
}

resource "aws_autoscaling_group" "web" {
  availability_zones   = ["eu-west-1a"]
  min_size             = 1
  max_size             = 3
  desired_capacity     = 2
  health_check_type    = "ELB"
  force_delete         = true
  launch_configuration = aws_launch_template.web.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "web_scale_down"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 120
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 20.0
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "web_scale_up"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 120
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50.0
  }
}



resource "aws_lb" "web" {
  name               = "web"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web.id]
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow HTTP/HTTPS inbound traffic"


  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["${data.http.ip.response_body}/32"]
  }


  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["${data.http.ip.response_body}/32"]

  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["${data.http.ip.response_body}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "test1"
  }
}

data "http" "ip" {
  url = "https://ifconfig.me/ip"
}

output "ip" {
  value = data.http.ip.response_body
}
