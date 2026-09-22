#!/bin/bash


cd /home/ec2-user/app

#1. 변수 설정
source .env

mkdir -p /home/ec2-user/nginx/logs
mkdir -p /home/ec2-user/fastapi/logs

# 권한 획득
aws ecr get-login-password --region "$ECR_REGION" \
  | docker login \
      --username AWS \
      --password-stdin "$ECR_REGISTRY"


# 이미지(Docker) Pull
docker compose --env-file .env -f docker-compose.yaml pull

# 컨테이너 배포
# 기존 컨테이너가 존재할 경우에만 실행

docker compose --env-file .env -f docker-compose.yaml up -d --remove-orphans

docker compose --env-file .env -f docker-compose.yaml ps
# 사용하지 않는 이미지 정리 (디스크 용량 확보 차원)
docker image prune -f