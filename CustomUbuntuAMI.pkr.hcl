packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "aws_access_key" {
  type    = string
  default = "${env("PKR_VAR_aws_access_key")}"
}

variable "aws_secret_key" {
  type    = string
  default = "${env("PKR_VAR_aws_secret_key")}"
}

variable "aws_region" {
  type    = string
  default = "ap-south-2"
}

variable "project_name" {
  type        = string
  default     = "UbuntuWithSSMAgent"
  description = "Name of the Project"
}

variable "iam_instance_profile" {
  type        = string
  default     = "EC2InstanceProfileForImageBuilder"
  description = "IAM Instance Profile to Use for the Packer EC2"
}

variable "architecture" {
  type        = string
  description = "CPU Architecture"

  validation {
    condition     = contains(["amd64", "arm64"], var.architecture)
    error_message = "Architecture must be either 'amd64' or 'arm64'."
  }
}

data "amazon-ami" "ubuntu" {
  filters = {
    name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-*-*-${var.architecture}-server-*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  region      = var.aws_region
  most_recent = true
  owners      = ["099720109477"] # Canonical
}

locals {
  timestamp    = regex_replace(timestamp(), "[- TZ:]", "")
  project_code = lower(var.project_name)
  arch_type = {
    "arm64" = "Gravitron"
    "amd64" = "x64"
  }
  ubuntu_version = regex(".*ubuntu-[a-z]+-([0-9]+\\.[0-9]+)-.*", data.amazon-ami.ubuntu.name)[0]
  common_tags = {
    "CreatedBy" = "TkM Packer"
  }
  dynamic_tags = {
    "Name"            = "Custom Ubuntu ${local.ubuntu_version} ${local.arch_type[var.architecture]} AMI"
    "Created On Date" = formatdate("DD-MMM-YYYY", timeadd(timestamp(), "5h30m"))
    "Purpose"         = "Ubuntu Custom AMI"
    "Platform"        = "${local.arch_type[var.architecture]}"
    "Architecture"    = "${var.architecture}"
    "Ubuntu Version"  = "${local.ubuntu_version}"
  }
}

source "amazon-ebs" "ubuntu-base-ami" {
  ami_name      = "ubuntu-${var.architecture}-${local.timestamp}"
  instance_type = lower(var.architecture) == "amd64" ? "t3.medium" : "t4g.medium"
  region        = var.aws_region
  source_ami    = data.amazon-ami.ubuntu.id
  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size = 32
    volume_type = "gp3"

    delete_on_termination = true
    encrypted             = true
  }
  encrypt_boot         = true
  ssh_username         = "ubuntu"
  iam_instance_profile = var.iam_instance_profile
  tags                 = merge(local.common_tags, local.dynamic_tags)
}

build {
  name = "ssmagent-ami-build"
  sources = [
    "source.amazon-ebs.ubuntu-base-ami"
  ]

  provisioner "shell" {
    script = "AMIBuild.sh"
  }

  post-processor "manifest" {
    output = "manifest.json"
  }

  post-processor "shell-local" {
    command = "powershell -File PostProcessor.ps1"
  }
}