locals{
    key_name = var.key_name
    tag_header = (var.owner != "" && var.environment != "" ) ? "${var.owner}-${var.environment}-" : (var.owner != "" ? "${var.owner}-" : "")
    vpc_id = data.aws_vpc.vpc.id
    ami_id = data.aws_ami.al2023.id
    sg_ids = data.aws_security_groups.security_groups.ids
    ec2_policy_arns = toset([
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
        "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    ])
    aws_private_subnet_ids = data.aws_subnets.subnets.ids
}