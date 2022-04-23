output "cluster_name"{
    value = aws_ecs_cluster.cluster.name
}

output "asg_name"{
    value = aws_autoscaling_group.ecs.name
}

output "capacity_provider"{
    value = aws_ecs_capacity_provider.ecs_capacity_provider.name
}