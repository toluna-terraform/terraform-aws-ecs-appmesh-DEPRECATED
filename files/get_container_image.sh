#!/bin/bash


eval "$(jq -r '@sh "XAPP_NAME=\(.app_name) XIMAGE_NAME=\(.image_name) XAWS_PROFILE=\(.aws_profile)"')"
is_local=$(cat ~/.aws/config | grep $XAWS_PROFILE || echo "false")
IMAGE_TAG="$(cut -d':' -f2 <<< $XIMAGE_NAME)"
ECR="$(cut -d'/' -f1 <<< $XIMAGE_NAME)"
if [[ $is_local != "false" ]];then
    {
        aws ecr describe-images --repository-name "$XAPP_NAME-main" --image-ids=imageTag=$IMAGE_TAG --profile $XAWS_PROFILE
        IMAGE="has_tag"
        } || {
        aws ecr describe-images --repository-name "$XAPP_NAME-main" --image-ids=imageTag=latest --profile $XAWS_PROFILE
        IMAGE="is_latest"
        } || {
        IMAGE="NULL"
    }
else
    {
        aws ecr describe-images --repository-name "$XAPP_NAME-main" --image-ids=imageTag=$IMAGE_TAG
        IMAGE="has_tag"
        } || {
        aws ecr describe-images --repository-name "$XAPP_NAME-main" --image-ids=imageTag=latest
        IMAGE="is_latest"
        } || {
        IMAGE="NULL"
    }
fi
if [[ $IMAGE == "has_tag" ]]; then
    jq -n --arg image "$XIMAGE_NAME" '{ "image": $image }'
    elif [[ $IMAGE == "is_latest" ]]; then
    jq -n --arg image "$ECR/$XAPP_NAME-main:latest" '{ "image": $image }'
else
    jq -n --arg image "$ECR/soa-base" '{ "image": $image }'
fi
