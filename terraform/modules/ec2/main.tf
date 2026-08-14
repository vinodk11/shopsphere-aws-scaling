data "aws_partition" "current" {}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.this.name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted  = true
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/bootstrap.sh.tftpl", {
    db_username        = var.db_username
    db_password        = var.db_password
    jwt_secret         = var.jwt_secret
    app_repo_url       = var.app_repo_url
    app_branch         = var.app_branch
    app_port           = var.app_port
    reverse_proxy_port = var.reverse_proxy_port
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-ec2"
  })
}
