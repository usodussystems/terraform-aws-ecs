#!/bin/bash
set -ex

echo ============= CONFIG =============

sudo yum update -yqq

rand=$(printf %03d $((1 + $RANDOM % 100)))
sudo hostnamectl set-hostname ${application}-${environment}-$(echo $rand)

cat<<EOF | sudo tee -a /etc/environment
AWS_DEFAULT_REGION=us-east-1
NODE_NAME=$(hostname)
EOF


# ECS config
# aws ecs put-account-setting --name awsvpcTrunking --value enabled --region ${region}

cat<<EOF | sudo tee /etc/ecs/ecs.config
ECS_CLUSTER=${cluster_name}
ECS_ENABLE_TASK_IAM_ROLE=true
ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
EOF

echo ${region}

echo "Configure files and ulimits vm"

sudo bash -c "
sysctl -w vm.max_map_count=524288
sysctl -w fs.file-max=131072
ulimit -n 131072
ulimit -u 8192
"
echo "Configure ulimit default to docker"

cat<<EOF | sudo tee /etc/sysconfig/docker
DAEMON_MAXFILES=1048576
OPTIONS="--default-ulimit nofile=1024000:1024000"
DAEMON_PIDFILE_TIMEOUT=10
EOF

sudo systemctl restart docker

echo ============= DONE =============