provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

#------------IAM---------------- 

resource "aws_iam_instance_profile" "s3_access_profile" {
  name = "s3_access"
  role = "${aws_iam_role.s3_access_role.name}"
}

resource "aws_iam_role_policy" "s3_access_policy" {
  name = "s3_access_policy"
  role = "${aws_iam_role.s3_access_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "s3_access_role" {
  name = "s3_access_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
  {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
  },
      "Effect": "Allow",
      "Sid": ""
      }
    ]
}
EOF
}

#-------------VPC-----------

resource "aws_vpc" "pau_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags {
    Name = "pau_vpc"
  }
}

#internet gateway

resource "aws_internet_gateway" "pau_internet_gateway" {
  vpc_id = "${aws_vpc.pau_vpc.id}"

  tags {
    Name = "pau_igw"
  }
}

# Route tables

resource "aws_route_table" "pau_public_rt" {
  vpc_id = "${aws_vpc.pau_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.pau_internet_gateway.id}"
  }

  tags {
    Name = "pau_public"
  }
}

resource "aws_default_route_table" "pau_private_rt" {
  default_route_table_id = "${aws_vpc.pau_vpc.default_route_table_id}"

  tags {
    Name = "pau_private"
  }
}

resource "aws_subnet" "pau_public1_subnet" {
  vpc_id                  = "${aws_vpc.pau_vpc.id}"
  cidr_block              = "${var.cidrs["public1"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "pau_public1"
  }
}

resource "aws_subnet" "pau_public2_subnet" {
  vpc_id                  = "${aws_vpc.pau_vpc.id}"
  cidr_block              = "${var.cidrs["public2"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "pau_public2"
  }
}

resource "aws_subnet" "pau_private1_subnet" {
  vpc_id                  = "${aws_vpc.pau_vpc.id}"
  cidr_block              = "${var.cidrs["private1"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "pau_private1"
  }
}

resource "aws_subnet" "pau_private2_subnet" {
  vpc_id                  = "${aws_vpc.pau_vpc.id}"
  cidr_block              = "${var.cidrs["private2"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "pau_private2"
  }
}

resource "aws_vpc_endpoint" "pau_private-s3_endpoint" {
  vpc_id       = "${aws_vpc.pau_vpc.id}"
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = ["${aws_vpc.pau_vpc.main_route_table_id}",
    "${aws_route_table.pau_public_rt.id}",
  ]

  policy = <<POLICY
{
    "Statement": [
        {
            "Action": "*",
            "Effect": "Allow",
            "Resource": "*",
            "Principal": "*"
        }
    ]
}
POLICY
}

resource "aws_subnet" "pau_rds1_subnet" {
  vpc_id                  = "${aws_vpc.pau_vpc.id}"
  cidr_block              = "${var.cidrs["rds1"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "pau_rds1"
  }
}

resource "aws_subnet" "pau_rds2_subnet" {
  vpc_id                  = "${aws_vpc.pau_vpc.id}"
  cidr_block              = "${var.cidrs["rds2"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "pau_rds2"
  }
}

resource "aws_subnet" "pau_rds3_subnet" {
  vpc_id                  = "${aws_vpc.pau_vpc.id}"
  cidr_block              = "${var.cidrs["rds3"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[2]}"

  tags {
    Name = "pau_rds3"
  }
}

resource "aws_route_table_association" "pau_public_assoc" {
  subnet_id      = "${aws_subnet.pau_public1_subnet.id}"
  route_table_id = "${aws_route_table.pau_public_rt.id}"
}

resource "aws_route_table_association" "pau_public2_assoc" {
  subnet_id      = "${aws_subnet.pau_public2_subnet.id}"
  route_table_id = "${aws_route_table.pau_public_rt.id}"
}

resource "aws_route_table_association" "pau_private1_assoc" {
  subnet_id      = "${aws_subnet.pau_private1_subnet.id}"
  route_table_id = "${aws_default_route_table.pau_private_rt.id}"
}

resource "aws_route_table_association" "pau_private2_assoc" {
  subnet_id      = "${aws_subnet.pau_private2_subnet.id}"
  route_table_id = "${aws_default_route_table.pau_private_rt.id}"
}

resource "aws_db_subnet_group" "pau_rds_subnetgroup" {
  name = "pau_rds_subnetgroup"

  subnet_ids = ["${aws_subnet.pau_rds1_subnet.id}",
    "${aws_subnet.pau_rds2_subnet.id}",
    "${aws_subnet.pau_rds3_subnet.id}",
  ]

  tags {
    Name = "pau_rds_sng"
  }
}

#Security groups

resource "aws_security_group" "pau_dev_sg" {
  name        = "pau_dev_sg"
  description = "Used for access to the dev instance"
  vpc_id      = "${aws_vpc.pau_vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.local_ip}"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.local_ip}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "pau_public_sg" {
  name        = "pau_public_sg"
  description = "Used for public and private instances for load balancer access"
  vpc_id      = "${aws_vpc.pau_vpc.id}"

  #HTTP 

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "pau_private_sg" {
  name        = "pau_private_sg"
  description = "Used for private instances"
  vpc_id      = "${aws_vpc.pau_vpc.id}"

  # Access from other security groups

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.vpc_cidr}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "pau_rds_sg" {
  name        = "pau_rds_sg"
  description = "Used for DB instances"
  vpc_id      = "${aws_vpc.pau_vpc.id}"

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"

    security_groups = ["${aws_security_group.pau_dev_sg.id}",
      "${aws_security_group.pau_public_sg.id}",
      "${aws_security_group.pau_private_sg.id}",
    ]
  }
}

#S3 bucket

resource "random_id" "pau_code_bucket" {
  byte_length = 2
}

resource "aws_s3_bucket" "code" {
  bucket        = "${var.domain_name}-${random_id.pau_code_bucket.dec}"
  acl           = "private"
  force_destroy = true

  tags {
    Name = "code bucket"
  }
}

#---------COMPUTE-----------

resource "aws_db_instance" "pau_db" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "5.6.27"
  instance_class         = "${var.db_instance_class}"
  name                   = "${var.dbname}"
  username               = "${var.dbuser}"
  password               = "${var.dbpassword}"
  db_subnet_group_name   = "${aws_db_subnet_group.pau_rds_subnetgroup.name}"
  vpc_security_group_ids = ["${aws_security_group.pau_rds_sg.id}"]
  skip_final_snapshot    = true
}

#key pair

resource "aws_key_pair" "pau_auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

#dev server

resource "aws_instance" "pau_dev" {
  instance_type = "${var.dev_instance_type}"
  ami           = "${var.dev_ami}"

  tags {
    Name = "pau_dev"
  }

  key_name               = "${aws_key_pair.pau_auth.id}"
  vpc_security_group_ids = ["${aws_security_group.pau_dev_sg.id}"]
  iam_instance_profile   = "${aws_iam_instance_profile.s3_access_profile.id}"
  subnet_id              = "${aws_subnet.pau_public1_subnet.id}"

}

#load balancer

resource "aws_elb" "pau_elb" {
  name = "${var.domain_name}-elb"

  subnets = ["${aws_subnet.pau_public1_subnet.id}",
    "${aws_subnet.pau_public2_subnet.id}",
  ]

  security_groups = ["${aws_security_group.pau_public_sg.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = "${var.elb_healthy_threshold}"
    unhealthy_threshold = "${var.elb_unhealthy_threshold}"
    timeout             = "${var.elb_timeout}"
    target              = "TCP:80"
    interval            = "${var.elb_interval}"
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "pau_${var.domain_name}-elb"
  }
}

#AMI 

resource "random_id" "golden_ami" {
  byte_length = 8
}

resource "aws_ami_from_instance" "pau_golden" {
  name               = "pau_ami-${random_id.golden_ami.b64}"
  source_instance_id = "${aws_instance.pau_dev.id}"

  provisioner "local-exec" {
    command = <<EOT
cat <<EOF > userdata
#!/bin/bash
/usr/bin/aws s3 sync s3://${aws_s3_bucket.code.bucket} /var/www/html/
/bin/touch /var/spool/cron/root
sudo /bin/echo '*/5 * * * * aws s3 sync s3://${aws_s3_bucket.code.bucket} /var/www/html/' >> /var/spool/cron/root
EOF
EOT
  }
}

#launch configuration

resource "aws_launch_configuration" "pau_lc" {
  name_prefix          = "pau_lc-"
  image_id             = "${aws_ami_from_instance.pau_golden.id}"
  instance_type        = "${var.lc_instance_type}"
  security_groups      = ["${aws_security_group.pau_private_sg.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.s3_access_profile.id}"
  key_name             = "${aws_key_pair.pau_auth.id}"
  user_data            = "${file("userdata")}"

  lifecycle {
    create_before_destroy = true
  }
}

#ASG 

resource "aws_autoscaling_group" "pau_asg" {
  name                      = "asg-${aws_launch_configuration.pau_lc.id}"
  max_size                  = "${var.asg_max}"
  min_size                  = "${var.asg_min}"
  health_check_grace_period = "${var.asg_grace}"
  health_check_type         = "${var.asg_hct}"
  desired_capacity          = "${var.asg_cap}"
  force_delete              = true
  load_balancers            = ["${aws_elb.pau_elb.id}"]

  vpc_zone_identifier = ["${aws_subnet.pau_private1_subnet.id}",
    "${aws_subnet.pau_private2_subnet.id}",
  ]

  launch_configuration = "${aws_launch_configuration.pau_lc.name}"

  tag {
    key                 = "Name"
    value               = "pau_asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

#---------Route53-------------

resource "aws_route53_zone" "primary" {
  name              = "${var.domain_name}.com"
  delegation_set_id = "${var.delegation_set}"
}

#www 

resource "aws_route53_record" "www" {
  zone_id = "${aws_route53_zone.primary.zone_id}"
  name    = "www.${var.domain_name}.com"
  type    = "A"

  alias {
    name                   = "${aws_elb.pau_elb.dns_name}"
    zone_id                = "${aws_elb.pau_elb.zone_id}"
    evaluate_target_health = false
  }
}

#dev 

resource "aws_route53_record" "dev" {
  zone_id = "${aws_route53_zone.primary.zone_id}"
  name    = "dev.${var.domain_name}.com"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.pau_dev.public_ip}"]
}

#secondary zone

resource "aws_route53_zone" "secondary" {
  name   = "${var.domain_name}.com"
  vpc_id = "${aws_vpc.pau_vpc.id}"
}

#db 

resource "aws_route53_record" "db" {
  zone_id = "${aws_route53_zone.secondary.zone_id}"
  name    = "db.${var.domain_name}.com"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_db_instance.pau_db.address}"]
}
