packer {
  required_plugins {
    docker = {
      source  = "github.com/hashicorp/docker"
      version = ">= 1.1.1"
    }
  }
}

source "docker" "nginx_custom" {
  image  = "nginx:latest"
  commit = true
}

build {
  sources = ["source.docker.nginx_custom"]

  provisioner "file" {
    source      = "../index.html"
    destination = "/usr/share/nginx/html/index.html"
  }

  post-processor "docker-tag" {
    repository = "nginx-custom"
    tag        = ["v1"]
  }
}
