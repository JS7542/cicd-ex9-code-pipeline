variable "key_name" {
    description = "키페어 이름"
    type        = string
    # 뭄바이 리전의 키 페어
    default     = "std20-cicd-keypair"
}

variable "owner" {
    description = "리소스 소유자"
    type        = string
    default     = "std20"
}

variable "environment" {
    description = "프로젝트 역할 구분"
    type        = string
    default     = "cicd"
}

variable "default_version" {
    description = "Launch Template의 기본 버전"
    type        = string
    default     = "latest"
}
