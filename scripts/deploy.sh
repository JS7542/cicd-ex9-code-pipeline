#!/bin/bash

#1. 변수 설정
AWS_REGION="ap-east-1"
ECR_REPOSITORY="nginx"
CONTAINER_NAME="nginx-app"
# 권한 획득
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com


# 이미지(Docker) Pull
docker pull $ECR_URI:latest


# 컨테이너 배포
# 기존 컨테이너가 존재할 경우에만 실행
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

docker run -d --name $CONTAINER_NAME -p 80:80 --restart always $ECR_URI:latest

# 사용하지 않는 이미지 정리 (디스크 용량 확보 차원)
docker image prune -f