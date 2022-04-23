locals {
  tags = {
    ModificationDate = timestamp()
    # Console | Terraform | Ansible | Packer
    Builder = "Terraform"
    # Client Infos
    Applictation = var.application
    Project      = var.project
    Environment  = local.environment[var.environment]
  }
  environment = {
    dev = "Development"
    prd = "Production"
    hml = "Homolog"
  }
  # name_pattern = format("%s-%s-%s", var.project, var.environment, local.resource)
  vpc_name                  = format("%s-%s-%s", var.project, var.environment, "vpc")
  iam_instance_role_name    = format("%s-%s-%s", var.project, var.environment, "ecs-instance-role")
  iam_instance_profile_name = format("%s-%s-%s", var.project, var.environment, "ecs-instance-profile")
  cluster_name              = format("%s-%s-%s", var.project, var.environment, "ecs-cluster")
  lt_ecs_name               = format("%s-%s-%s", var.project, var.environment, "lt-ecs")
  asg_name                  = format("%s-%s-%s", var.project, var.environment, "asg-ecs")
  ecs_instance_name         = format("%s-%s-%s", var.project, var.environment, "ecs-spot")
  capacity_provider_name    = format("%s-%s-%s", var.project, var.environment, "ecs-cp-spot")
  ssh_key_name              = format("%s-%s-%s", var.project, var.environment, "ecs-instances-key")

}

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}


##
# IAM
##

resource "aws_iam_role" "instance_role" {
  name               = local.iam_instance_role_name
  path               = "/ecs/"
  assume_role_policy = data.aws_iam_policy_document.ec2_ecs_assume_role.json

  inline_policy {
    name   = "includeTaskRegistration"
    policy = data.aws_iam_policy_document.inline_policy.json
  }
}

resource "aws_iam_instance_profile" "ecs" {
  name = local.iam_instance_profile_name
  role = aws_iam_role.instance_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_ec2_role" {
  role       = aws_iam_role.instance_role.id
  policy_arn = data.aws_iam_policy.AmazonEC2ContainerServiceforEC2Role.arn
}

resource "aws_iam_role_policy_attachment" "ecs_ec2_cloudwatch_role" {
  role       = aws_iam_role.instance_role.id
  policy_arn = data.aws_iam_policy.CloudWatchLogsFullAccess.arn
}


resource "aws_launch_template" "ecs" {
  name                   = local.lt_ecs_name
  update_default_version = true

  # block_device_mappings {
  #   device_name = "/dev/sda1"
  #   ebs {
  #     volume_size = 20
  #   }
  # }

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs.name
  }

  image_id      = data.aws_ami.ecs.id
  instance_type = var.instance_type

  instance_market_options {
    market_type = "spot"
    spot_options {
      # block_duration_minutes = 360
      max_price = 0.04
    }
  }

  key_name = aws_key_pair.ecs.key_name

  monitoring {
    enabled = true
  }

  vpc_security_group_ids = [var.security_group_id]

  tag_specifications {
    resource_type = "instance"
    tags = merge({
      Name         = "ECS - Cluster Spot"
      CreationDate = timestamp()
      },
    local.tags)
  }
  user_data = base64encode(data.template_file.ecs_userdata.rendered)

  tags = local.tags
}


resource "aws_autoscaling_group" "ecs" {
  name                = local.asg_name
  vpc_zone_identifier = var.private_subnet_ids
  max_size            = var.environment == "prd" ? 50 : 3
  min_size            = 0

  default_cooldown = 30

  force_delete = true

  launch_template {
    id      = aws_launch_template.ecs.id
    version = aws_launch_template.ecs.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  dynamic "tag" {
    for_each = concat(
      tolist([
        tomap({ "key" = "Name", "value" = local.ecs_instance_name, "propagate_at_launch" = true }),
        tomap({ "key" = "AmazonECSManaged", "value" = "", "propagate_at_launch" = true }),
        ]
      )
    )
    content {
      key                 = tag.value.key
      value               = tag.value.value
      propagate_at_launch = tag.value.propagate_at_launch
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_service_linked_role" "ecs" {
  count            = 0
  aws_service_name = "ecs.amazonaws.com"
}

resource "aws_ecs_capacity_provider" "ecs_capacity_provider" {
  name = local.capacity_provider_name
  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 3
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = var.environment == "prd" ? 75 : 100
    }
  }
  depends_on = [
    aws_iam_instance_profile.ecs
  ]
}

resource "aws_autoscaling_schedule" "scale_in" {
  scheduled_action_name  = "asg-scale-in"
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  recurrence             = "0 14 * * *"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
}

resource "aws_autoscaling_schedule" "scale_out" {
  scheduled_action_name  = "asg-scale-out"
  min_size               = 0
  max_size               = 3
  desired_capacity       = 1
  recurrence             = "0 09 * * *"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
}

resource "random_id" "name" {
  byte_length = 4
  prefix      = format("%s-", "random")
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
  # ecdsa_curve = var.ecdsa_curve
}

resource "null_resource" "download_private_key" {
  provisioner "local-exec" {
    command = format("echo '%s' > %s.pem && chmod %s %s.pem", tls_private_key.key.private_key_pem, random_id.name.hex, "400", random_id.name.hex)
  }
}

resource "aws_key_pair" "ecs" {
  key_name   = local.ssh_key_name
  public_key = chomp(tls_private_key.key.public_key_openssh)
}


resource "aws_ecs_cluster" "cluster" {
  name = local.cluster_name
  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "cluster" {
  cluster_name = aws_ecs_cluster.cluster.name
  capacity_providers = [
    aws_ecs_capacity_provider.ecs_capacity_provider.name
  ]
  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ecs_capacity_provider.name
    base              = 1
    weight            = 1
  }
}
