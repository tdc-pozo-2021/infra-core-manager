variable "git_config" {
  type = object({
    owner = string
    token = string
  })
}

variable "default_tags" {
  type    = map(string)
  default = {}
}

variable "name" {
  type = string
}

variable "template_repository_enabled" {
  type = bool
  default = false
}

variable "template_repository_name" {
  type = string
  default = null
}

variable "create_repo" {
  type = bool
  default = true
}

variable "power_access_enabled" {
  type = bool
  default = false
}

variable "custom_policy" {
  type = map(any)
  default = null
}