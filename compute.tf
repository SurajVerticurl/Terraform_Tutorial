resource "aws_instance" "this" {
  ami                         = "ami-05c13eab67c5d8861"
  instance_type               =  var.instance_type
  key_name                    =  var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.allow_port.id]
  subnet_id               = aws_subnet.publicsubnet1a.id
  tags                        = {
     Name = "Suraj"
     }
}
resource "aws_security_group" "allow_port" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "TLS from VPC"
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
    Name = "allow_tls"
  }
}
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
     Name = "Surajvpc"
     }
}
resource "aws_subnet" "publicsubnet1a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public_subnet_one"
  }
}
resource "aws_subnet" "publicsubnet1b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "public_subnet_two"
  }
}
resource "aws_subnet" "publicsubnet1c" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "public_subnet_three"
  }
}
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "public_route_table"
  }
}
resource "aws_route_table_association" "public_route_table_1a_association" {
  subnet_id      = aws_subnet.publicsubnet1a.id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_route_table_association" "public_route_table_1b_association" {
  subnet_id      = aws_subnet.publicsubnet1b.id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_route_table_association" "public_route_table_1c_association" {
  subnet_id      = aws_subnet.publicsubnet1c.id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "SurajInternetGateway"
  }
}
resource "aws_route" "Suraj_route" {
  route_table_id            = aws_route_table.public_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.gw.id
}


------------------Auto Scaling Group -----------------------


# Creating a Launch Configuration for ASG

resource "aws_launch_configuration" "main" {
  name = "suraj_launch_config"
  image_id = "ami-05c13eab67c5d8861"
  instance_type = var.instance_type
  key_name = var.key_name

}


# Auto Scaling Group
resource "aws_autoscaling_group" "suraj_asg" {
  name                 = "suraj-autoscale_group"
  desired_capacity     = 1
  max_size             = 3
  min_size             = 1
  vpc_zone_identifier  = [aws_subnet.publicsubnet1a.id, aws_subnet.publicsubnet1b.id, aws_subnet.publicsubnet1c.id]
  health_check_type    = "EC2"
  health_check_grace_period = 30
  force_delete         = true

  launch_configuration = aws_launch_configuration.main.id

  tag {
    key                 = "name"
    value               = "suraj_asg"
    propagate_at_launch = true
  }
}

# Auto Scaling Policy for CPU Usage
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "suraj_scale_up_policy"
  scaling_adjustment    = 1
  adjustment_type       = "ChangeInCapacity"
  cooldown              = 30
  autoscaling_group_name = aws_autoscaling_group.suraj_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm_high" {
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 30
  statistic           = "Average"
  threshold           = 5 # percentage of usage
  alarm_description   = "Scale up when CPU is high"
  alarm_name          = "scale_up_when_cpu_high"
  actions_enabled     = true

  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}
