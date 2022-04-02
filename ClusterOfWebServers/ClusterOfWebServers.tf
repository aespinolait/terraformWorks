#variables
variable "server_port" {
  description = "The port the server will user for HTTP requests"
  type = number
  default = 8080
}

#outputs
output "server_data" {
  description = "Public DNS, IP and LoadBalancer of instance"
  value = [aws_lb.example_loadbalancer.dns_name]
}

# Providers
provider "aws" {
  region = "us-east-1"
}

#AWS data
data "aws_vpc" "vpc_info" {
  default = true
}

data "aws_subnet_ids" "subnet_info" {
  vpc_id = data.aws_vpc.vpc_info.id
}

#Instance Information
resource "aws_launch_configuration" "Servers" {
  image_id = "ami-0e472ba40eb589f49"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.http.id]

  user_data = <<-EOF
    #!/bin/bash
    echo "Hello, World" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
    EOF

  lifecycle {
    create_before_destroy = true
  }
}

#Security Groups
resource "aws_security_group" "http" {
    name = "terraform-example-instance"
    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "load_balancer_sg" {
  name = "lb incoming group"
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }
# Allow all outbound requests
   egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    }
  }

#ASG Config
resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.Servers.name
  vpc_zone_identifier = data.aws_subnet_ids.subnet_info.ids

  target_group_arns = [aws_lb_target_group.asg_target_group.id]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
      key = "Name"
      value = "terraforms-asg-example"
      propagate_at_launch = true
  }
}

#Load Balancer Config - type
resource "aws_lb" "example_loadbalancer" {
  name = "terraform-asg-example"
  load_balancer_type = "application"
  subnets =  data.aws_subnet_ids.subnet_info.ids
  security_groups = [aws_security_group.load_balancer_sg.id]
}

#Load Balancer Config - listeners
resource "aws_lb_listener" "example_listener" {
  load_balancer_arn = aws_lb.example_loadbalancer.arn
  port = 80
  protocol = "HTTP"

  #By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
        content_type = "text/plain"
        message_body = "404: page not found"
        status_code = 404
    }
  }
}

#LB Target group
resource "aws_lb_target_group" "asg_target_group" {
  name = "terraform-asg-example"
  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.vpc_info.id

  health_check {
    path = "/"
    protocol ="HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

#LB listener rules
resource "aws_lb_listener_rule" "lb_listener" {
  listener_arn = aws_lb_listener.example_listener.arn
  priority = 100

    condition {
        path_pattern {
            values = ["*"]
        }
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg_target_group.arn
  }
}