data "aws_ami" "al2023" {
    most_recent = true
    filter {
        name   = "name"
        values = ["al2023-ami-2023.*-x86_64"]
    }
    owners = ["amazon"]
}

data "aws_vpc" "vpc"{
    filter {
      name = "tag:Name"
      values = ["${local.tag_header}vpc"]
    }
}

# # 한번에 여러개의 보안 그룹을 조회하기 위한 데이터 소스
# # values 내부의 , 는 or 조건으로 작동함.
# # vpc_security_group_ids = data.aws_security_groups.security_groups.ids 로 작동
data "aws_security_groups" "security_groups" {
    filter {
        name   = "tag:Name"
        values = [
        "${local.tag_header}external-alb-sg",
        "${local.tag_header}bastion-sg",
        ]
    }
}

# # 보안그룹 하나씩 추출
# # ALB 보안그룹
# # vpc_security_group_ids =[data.aws_security_group.external_alb_sg.id, data.aws_security_group.bastion_sg.id] 로 작동
# data "aws_security_group" "external_alb_sg" {
#     filter {
#         name   = "tag:Name"
#         values = ["${local.tag_header}external-alb-sg"]
#     }
# }

# # SSH 보안그룹
# data "aws_security_group" "bastion_sg" {
#     filter {
#         name   = "tag:Name"
#         values = ["${local.tag_header}bastion-sg"]
#     }
# }

data "aws_subnets" "subnets" {
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.vpc.id]
    }
    filter {
        name   = "tag:Type"
        values = ["private"]
    }
}

output "information" {
    value = [
        local.vpc_id,
        data.aws_security_groups.security_groups.ids,
        # data.aws_security_group.external_alb_sg.id,
        # data.aws_security_group.bastion_sg.id
    ]
}
