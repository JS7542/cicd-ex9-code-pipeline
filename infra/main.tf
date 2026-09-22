# =================================================================
# 서비스에 사용할 역할 생성
# =================================================================

resource "aws_iam_role" "node_asg_service_role" {
    name = "${local.tag_header}node-asg-service-role"

    assume_role_policy = jsonencode(
        {
            Version = "2012-10-17"
            Statement = [
                {
                    Effect = "Allow"
                    Principal = {
                        Service = "ec2.amazonaws.com"
                    }
                    Action = "sts:AssumeRole"   # 신뢰관계 허용(**임시 권한** : IAM Role 을 임시로 획득하여 권한을 행사)
                }
            ]
        }
    )
}

# 정책 연결

resource "aws_iam_role_policy_attachment" "node_asg_policies_attachment" {
    for_each = local.ec2_policy_arns

    role       = aws_iam_role.node_asg_service_role.name
    policy_arn = each.value
}

# 인스턴스 프로필 생성

resource "aws_iam_instance_profile" "node_asg_instance_profile" {
    name = "${local.tag_header}node-asg-instance-profile"
    role = aws_iam_role.node_asg_service_role.name
}

# ================================================================================
# CodeDeploy 역할(Role)
# --------------------------------------------------------------------------------
# 역할 생성
resource "aws_iam_role" "codedeploy_role" {
  name = "${local.tag_header}codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
      Action    = "sts:AssumeRole" # IAM Role을 임시로 획득하여 권한을 행사할 수 있도록 허용
    }]
  })
}

# 관리형 정책을 역할에 연결
resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}


# ================================================================================
# CodePipeline 서비스에서 사용할 IAM Role 생성
# --------------------------------------------------------------------------------
resource "aws_iam_role" "codepipeline_role" {
  name = "${local.tag_header}codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole" # IAM Role을 임시로 획득하여 권한을 행사할 수 있도록 허용
    }]
  })
}

# 각 서비스에 대한 접근 권한(정책) 생성
resource "aws_iam_role_policy" "codepipeline_policy" {
  name          = "${local.tag_header}codepipeline-policy"
  role          = aws_iam_role.codepipeline_role.id


  policy = jsonencode(
    {
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "s3:GetObject",
                    "s3:PutObjectAcl",
                    "s3:GetObjectVersion",
                    "s3:GetBucketVersioning",
                    "s3:PutObject",
                ]
                Resource = "*"
            },
            {
                Effect = "Allow"
                Action = [          
                    "codebuild:BatchGetBuilds",
                    "codebuild:StartBuild",
                ]
                Resource = "*"
            },
            {
                Effect = "Allow"
                Action = [
                    "codedeploy:CreateDeployment",
                    "codedeploy:GetApplication",
                    "codedeploy:GetApplicationRevision",
                    "codedeploy:GetDeployment",
                    "codedeploy:GetDeploymentConfig",
                    "codedeploy:RegisterApplicationRevision",
                ]
                Resource = "*"
            }
        ]
    }
  )
}



# =================================================================
# Pipeline 저장용 S3 버킷
# =================================================================
# byte_length에 정의된 자릿수의 임의 숫자 반환
resource "random_id" "s3_bucket_id" {
  byte_length = 4
}

# Pipeline 구성에 필요한 배포 파일 저장소 생성

resource "aws_s3_bucket" "pipeline_bucket" {
    bucket = "${local.tag_header}pipeline-${random_id.s3_bucket_id.hex}"
    force_destroy = true

    tags = {
        Name = "${local.tag_header}pipeline-${random_id.s3_bucket_id.hex}"
    }
}

# 생성된 버킷의 버전 관리 활성화(CodePipeline에서 필수 요구사항)
resource "aws_s3_bucket_versioning" "pipeline_bucket_versioning" {
    bucket = aws_s3_bucket.pipeline_bucket.id
    versioning_configuration {
        status = "Enabled"
    }
}

# 퍼블릭 액세스 차단 설정(보안 규정 준수)
resource "aws_s3_bucket_public_access_block" "pipeline_bucket_public_access_block" {
    bucket = aws_s3_bucket.pipeline_bucket.id

    block_public_acls       = true
    ignore_public_acls      = true
    block_public_policy     = true
    restrict_public_buckets = true
}


# 서버측 기본 암호화 설정

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_bucket_sse" {
    bucket = aws_s3_bucket.pipeline_bucket.id

    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = "AES256" # SSE-S3
        }
    }
}

# =================================================================
# Launch Template & User Data
# =================================================================
# Launch Template 생성
resource "aws_launch_template" "asg_lt" {
    name_prefix   = "${local.tag_header}asg-lt-"
    image_id      =  local.ami_id # data.aws_ami.al2023.id
    instance_type = "t3.small"
    key_name      = local.key_name
    vpc_security_group_ids = local.sg_ids
    # vpc_security_group_ids =[
    #     data.aws_security_group.external_alb_sg.id,
    #     data.aws_security_group.bastion_sg.id
    # ]
    # 기본 버전 지정 방법 -----------------------------------------
    update_default_version = var.default_version == "latest" ? true : false
    default_version = var.default_version != "latest" ? tostring(var.default_version) : null
    # ------------------------------------------------------------

    iam_instance_profile {
    name = aws_iam_instance_profile.node_asg_instance_profile.name
    }


      user_data = base64encode(<<-EOF
                #!/bin/bash
                dnf update -y
                # ruby: CodeDeploy서비스 개발 언어, codedeploy-agent 설치를 위해 반드시 필요
                dnf install -y ruby wget docker

                systemctl start docker
                systemctl enable docker
                usermod -aG docker ec2-user
                wget -q \
                "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
                -O /usr/local/lib/docker/cli-plugins/docker-compose

                chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

                # 설치 확인
                docker --version
                docker compose version
                cd /tmp
                wget https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/latest/install
                chmod +x ./install
                ./install auto

                systemctl start codedeploy-agent
                systemctl enable codedeploy-agent
              EOF
  )
  
    tag_specifications {
        resource_type = "instance"
        tags = {
            Name = "${local.tag_header}asg-node-instance"
        }
    }
}

# =================================================================
# Auto Scaling Group 생성
# =================================================================

resource "aws_autoscaling_group" "asg" {
    name = "${local.tag_header}codedeploy-asg"
    min_size = 1
    max_size = 3
    desired_capacity = 2
    vpc_zone_identifier = local.aws_private_subnet_ids
    launch_template {
        id      = aws_launch_template.asg_lt.id
        version = "$Latest"
    }
}

# =================================================================
# CodeDeploy Application & Deployment Group 생성
# =================================================================

resource "aws_codedeploy_app" "app" {
    name = "${local.tag_header}asg-codedeploy-app"
    # 배포 대상 정의: Server / Lambda / ECS (EKS 없음)
    compute_platform = "Server"

}

resource "aws_codedeploy_deployment_group" "dg" {
    deployment_group_name = "${local.tag_header}asg-codedeploy-dg"
    # CodeDeploy_app 리소스 이름
    app_name = aws_codedeploy_app.app.name
    # codedeploy 서비스에 추가해줄 역할
    service_role_arn = aws_iam_role.codedeploy_role.arn
    # 배포 대상 정의
    autoscaling_groups = [aws_autoscaling_group.asg.name]
    

    # 배포 전략(구성) 지정
    # "CodeDeployDefault.AllAtOnce": 타겟 인스턴스 전체에 동시에 배포
    # "CodeDeployDefault.HalfAtATime": 타겟 인스턴스 절반씩 배포
    # "CodeDeployDefault.OneAtATime": 타겟 인스턴스 한 대씩 배포
    deployment_config_name = "CodeDeployDefault.AllAtOnce"

}

# =================================================================
# 연결 리소스 생성 및 CodePipeline 리소스 생성
# =================================================================
# AWS - GitHub 간 CodeStar Connection 생성
# -----------------------------------------------------------------

resource "aws_codestarconnections_connection" "github" {
    name = "${local.tag_header}github-connection"
    provider_type = "GitHub"
}

# =================================================================
# AWS CodePipeline 리소스 생성
# =================================================================

resource "aws_codepipeline" "pipeline" {
    name = "${local.tag_header}asg-cicd-codepipeline"
    role_arn = aws_iam_role.codepipeline_role.arn

    artifact_store {
        type = "S3"
        location = aws_s3_bucket.pipeline_bucket.bucket
    }

    # ------------------------------------------
    # Stage 1: Source
    # ------------------------------------------
    stage {
        name = "Source"
        action {
            name = "Source"
            category = "Source"
            owner = "AWS"   # 액션 제공자
            provider = "CodeStarSourceConnection"
            version = "1"
            output_artifacts = ["source_output"]
            configuration = {
                # 해당 GitHub 와 CodeDeploy 연결하는 연결 객체 정의
                ConnectionArn = aws_codestarconnections_connection.github.arn
                FullRepositoryId = "JS7542/cicd-ex9-code-pipeline"
                BranchName = "main"
            }
        }
    }
     # ------------------------------------------
    # Stage 2: Deploy
    # ------------------------------------------
    stage {
        name = "Deploy"
        action {
            name = "Deploy"
            category = "Deploy"
            owner = "AWS"   # 액션 제공자
            provider = "CodeDeploy"
            version = "1"
            input_artifacts = ["source_output"]     # stage 1 의 output_artifacts 에 정의된 이름
            configuration = {
                # 배포 서비스 이름
                ApplicationName = aws_codedeploy_app.app.name
                # 배포 진행할 CodeDeploy Deployment Group 이름
                DeploymentGroupName = aws_codedeploy_deployment_group.dg.deployment_group_name
            }
        }
    } 
}