#!/bin/sh
#
# Copy the local secrets.yaml file to S3.

REGION='us-east-1'

SCRIPTNAME=$(basename "$0")

if [ -n "$1" ]; then
  TAG="-${1}"
else
  TAG=""
fi

FILENAME="secrets${TAG}.yaml"

LOCAL="data/${FILENAME}"
REMOTE="s3://rk-devops-${REGION}/secrets/${FILENAME}"

if [ "$SCRIPTNAME" = 'storeSecrets.sh' ]; then
  SOURCE="$LOCAL"
  TARGET="$REMOTE"
  ACTION='store'
elif [ "$SCRIPTNAME" = 'getSecrets.sh' ]; then
  SOURCE="$REMOTE"
  TARGET="$LOCAL"
else
  echo "'$SCRIPTNAME' is not an invocation I understand."
  exit 1
fi

if [[ ("$ACTION" = "store") && (! -r "$LOCAL") ]]; then
  echo "Unable to read '$LOCAL', exiting."
  exit 1
fi

aws s3 cp $SOURCE $TARGET
