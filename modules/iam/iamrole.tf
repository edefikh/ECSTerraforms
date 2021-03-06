data "aws_caller_identity" "current" {}

###

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.app_name}-${var.environment}-ec2-profile"
  role = "${aws_iam_role.main.name}"
}

###

resource "aws_iam_role" "main" {
  name               = "${var.app_name}-${var.environment}-iam"
  description        = "Main IAM Role for cluster's EC2s"
  assume_role_policy = "${file( "${path.module}/policies/assumerole.json" )}"
}

###

resource "aws_iam_role_policy" "ecs" {
  name   = "${var.app_name}-${var.environment}-ecs"
  role   = "${aws_iam_role.main.id}"
  policy = "${file( "${path.module}/policies/ecs.json" )}"
}

###

data "template_file" "ecs-cluster" {
  template = "${file( "${path.module}/policies/ecs-cluster.json" )}"

  vars {
    app_name    = "${var.app_name}"
    environment = "${var.environment}"
    aws_region  = "${var.aws_region}"
    accountid   = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_iam_role_policy" "ecs-cluster" {
  name   = "${var.app_name}-${var.environment}-ecs-cluster"
  role   = "${aws_iam_role.main.id}"
  policy = "${data.template_file.ecs-cluster.rendered}"
}

###

data "template_file" "cluster-instance" {
  template = "${file( "${path.module}/policies/cluster-instance.json" )}"

  vars {
    app_name    = "${var.app_name}"
    environment = "${var.environment}"
    aws_region  = "${var.aws_region}"
    accountid   = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_iam_role_policy" "cluster-instance" {
  name   = "${var.app_name}-${var.environment}-cluster-instance"
  role   = "${aws_iam_role.main.id}"
  policy = "${data.template_file.cluster-instance.rendered}"
}

###

resource "aws_iam_role_policy" "ecr" {
  name   = "${var.app_name}-${var.environment}-ecr"
  role   = "${aws_iam_role.main.id}"
  policy = "${file( "${path.module}/policies/ecr.json" )}"
}

### 

resource "aws_iam_role_policy" "autoscaling" {
  name   = "${var.app_name}-${var.environment}-autoscaling"
  role   = "${aws_iam_role.main.id}"
  policy = "${file( "${path.module}/policies/autoscaling.json" )}"
}

### Allow access to special bucket which stores file with hostnames.###

data "template_file" "s3-hostname" {
  template = "${file( "${path.module}/policies/s3-hostname.json" )}"

  vars {
    s3_for_hostname_file = "${var.s3_for_hostname_file}"
  }
}

resource "aws_iam_role_policy" "s3-hostname" {
  name   = "${var.app_name}-${var.environment}-s3-hostname"
  role   = "${aws_iam_role.main.id}"
  policy = "${data.template_file.s3-hostname.rendered}"
}

### Allow instances to set tags. ### 

data "template_file" "instance-tags" {
  template = "${file( "${path.module}/policies/instance-tags.json" )}"

  vars {
    aws_region = "${var.aws_region}"
    accountid  = "${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_iam_role_policy" "instance-tags" {
  name   = "${var.app_name}-${var.environment}-instance-tags"
  role   = "${aws_iam_role.main.id}"
  policy = "${data.template_file.instance-tags.rendered}"
}

### Allow instances to get Logs credentials from secret's file at S3 bucket. ###

data "template_file" "s3-secrets" {
  template = "${file( "${path.module}/policies/secrets.json" )}"
}

resource "aws_iam_role_policy" "s3-secrets" {
  name   = "${var.app_name}-${var.environment}-s3-secrets"
  role   = "${aws_iam_role.main.id}"
  policy = "${data.template_file.s3-secrets.rendered}"
}

###

resource "aws_iam_role_policy" "iam_ssh_ec2" {
  count = "${length(var.iam_users_for_ec2_ssh)}"
  name  = "${var.app_name}-${var.environment}-iam-ssh-${element(concat(var.iam_users_for_ec2_ssh, list("")), count.index)}"
  role  = "${aws_iam_role.main.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": "iam:ListUsers",
        "Resource": "*"
    },
    {
        "Effect": "Allow",
        "Action": [
            "iam:GetSSHPublicKey",
            "iam:ListSSHPublicKeys"
        ],
        "Resource": "arn:aws:iam::${var.account_id}:user/${element(concat(var.iam_users_for_ec2_ssh, list("")), count.index)}"
    }
 ]
}
EOF
}
