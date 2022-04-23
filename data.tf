/**
 * Available zones
 */

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Definições de policies 

data "aws_iam_policy_document" "ec2_ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "app_ecs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["application-autoscaling.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ec2_ecs_scalling_role" {
  statement {
    sid    = "ECSUpdateService"
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "ecs:PutAccountSetting"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECSIncludeEC2Permission"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances"
    ]
    resources = ["*"]
  }

  statement {
    actions   = ["iam:PassRole"]
    effect    = "Allow"
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "iam:PassedToService"

      values = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy" "CloudWatchLogsFullAccess" {
  arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

data "aws_iam_policy" "AmazonEC2ContainerServiceforEC2Role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

data "aws_iam_policy_document" "inline_policy" {
  statement {
    actions = [
      "ecs:RegisterTaskDefinition",
      "ssm:PutParameter",
      "ssm:GetParameter",
    ]
    resources = ["*"]
  }
}

# Definição de Configs

data "aws_ami" "ecs" {
  most_recent = true
  name_regex  = "amzn2-ami-ecs-hvm-2.0.*-x86_64-ebs"
                #  amzn2-ami-ecs-hvm-2.0.20220328-x86_64-ebs
  owners = ["591542846629"]
}

data "template_file" "ecs_userdata" {
  template = file("${path.module}/data/templates/scripts/ecs_userdata.sh.tpl")
  vars = {
    application  = "ecs"
    cluster_name = local.cluster_name 
    region       = var.region
    environment  = var.environment
  }
}




