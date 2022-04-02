#variables
variable "server_port" {
  description = "The port the server will user for HTTP requests"
  type = number
  default = 8080
}

output "server_data" {
  description = "Public DNS and IP of instance"
  value = [aws_instance.Server.public_dns,aws_instance.Server.public_ip]
}

# provider
provider "aws" {
  region = "us-east-1"
}

#resources
resource "aws_instance" "Server" {
  ami = "ami-0e472ba40eb589f49"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.http.id]

  user_data = <<-EOF
    #!/bin/bash
    echo "Hello, World" > index.html
    nohup busybox httpd -f -p ${var.server_port} &
    EOF

  tags = {
      Name = "Terraform-example"
  }
}

resource "aws_security_group" "http" {
    name = "terraform-example-instance"
    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}