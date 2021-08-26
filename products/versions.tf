terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.55.0"
    }
    github = {
      source  = "hashicorp/github"
    }
    random = {
      source = "hashicorp/random"
      version = "3.1.0"
    }
  }
}

