
# =================================================================
# 테라폼 기본 설정
# =================================================================

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~>6.0" # 6.0~<7.0
    }
  }
  
}

provider "aws" {
  region = "ap-south-1" # AWS CLI 환경설정값이 우선함.

  # 기본 태그 설정: 태라폼으로 생성한 리소스들에 추가
  default_tags {
    tags  =  {
        Class = "bipa17"
        Owner = "std20"
        }
  }
}