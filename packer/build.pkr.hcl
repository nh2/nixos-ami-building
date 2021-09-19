packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.1, < 2.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  timestamp = formatdate("YYYY-MM-DD-hh_mm", timestamp())
}

# Variables
variable "location" {
  type        = string
  default     = "us-east-1"
}

## Credentials
variable "access_key" {
  type      = string
  default   = "${env("AWS_ACCESS_KEY_ID")}"
  sensitive = true
}

variable "secret_access_key" {
  type      = string
  default   = "${env("AWS_SECRET_ACCESS_KEY")}"
  sensitive = true
}

source "amazon-ebs" "nixos_example" {
  access_key = var.access_key
  secret_key = var.secret_access_key
  region     = var.location
  ami_name   = "nixos-packer-example {local.timestamp}"
  source_ami_filter {
    filters = {
      architecture = "x86_64"
    }
    most_recent = true
    owners      = ["080433136561"]
  }
  instance_type = "t2.micro"
  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    volume_size           = 40
    volume_type           = "gp2"
  }
  ssh_username = "root"
}

# Builders
build {
  sources = ["source.amazon-ebs.nixos_example"]

  provisioner "file" {
    destination = "/tmp/configuration.nix"
    source      = "../nixos/configuration.nix"
  }

  provisioner "shell" {
    execute_command = "sudo -S env {{ .Vars }} {{ .Path }}"
    inline = [
      "mv /tmp/configuration.nix /etc/nixos/configuration.nix",
      "nixos-rebuild switch --upgrade",
      "nix-collect-garbage -d",
      "rm -rf /etc/ec2-metadata /etc/ssh/ssh_host_* /root/.ssh"
    ]
  }
}
