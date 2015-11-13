#!/bin/bash
#
# Spin up an instance to make a new gold master.

if [ -r ".env" ]; then
  . .env
else
  echo "Populate .env first."
  exit 1
fi

# look up resource IDs
BUILD_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${BUILD_VPC}" | jq -r '.Vpcs | last | .VpcId')
SG_FILTER=$(echo -n '.SecurityGroups | map({GroupName, GroupId}) | map(select(.GroupName | test("' && echo -n "^${BUILD_VPC}-${BUILD_SECURITY_GROUP}-.*$" && echo -n '")))[] | .GroupId')
BUILD_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=${BUILD_VPC_ID}" | jq -r "$SG_FILTER")
BUILD_SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${BUILD_VPC_ID}" "Name=tag:Name,Values=${BUILD_SUBNET}" | jq -r '.Subnets | last | .SubnetId')

# create instance
INSTANCE_DATA=$(aws ec2 run-instances \
  --image-id "$AWS_LINUX_AMI" \
  --key-name "$BUILD_SSH_KEYPAIR" \
  --security-group-ids "$BUILD_SECURITY_GROUP_ID" \
  --instance-type "$BUILD_INSTANCE_TYPE" \
  --subnet-id "$BUILD_SUBNET_ID" \
  --iam-instance-profile "Name=${BUILD_PROFILE_NAME}")

INSTANCE_ID=$(echo $INSTANCE_DATA | jq -r '.Instances[].InstanceId')

# tag instance
sleep 5
aws ec2 create-tags --resources $INSTANCE_ID --tags "Key=Name,Value=datahub-gold-master"

echo $INSTANCE_ID
INSTANCE_HOSTNAME=''

# wait for hostname
while [ -z "$INSTANCE_HOSTNAME" ]; do
  sleep 2
  INSTANCE_HOSTNAME=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID | jq -r '.Reservations[].Instances[].PrivateDnsName')

  if [ "$INSTANCE_HOSTNAME" = "null" ]; then
    INSTANCE_HOSTNAME=''
  fi
done

# wait for the instance to be up
INSTANCE_STATE=''
while [ "$INSTANCE_STATE" != 'running' ]; do
  sleep 2
  INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID | jq -r '.Reservations[].Instances[].State.Name')
done

echo $INSTANCE_HOSTNAME
