variable "git_config" {
  type = object({
    owner = string
    token = string
  })
}

variable "products" {
  type = list(object({
    name                        = string
    default_tags                = map(string)
    template_repository_enabled = bool
    template_repository_name    = string
    create_repo                 = bool
    power_access_enabled        = bool
  }))
}