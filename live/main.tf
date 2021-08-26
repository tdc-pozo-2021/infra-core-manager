module "products" {
    source = "../../../../modules/products"
    for_each = { for product in var.products : product.name => product}
    name = each.value.name
    git_config = var.git_config
    default_tags = each.value.default_tags
    template_repository_enabled = each.value.template_repository_enabled
    template_repository_name = each.value.template_repository_name
    create_repo = each.value.create_repo
    power_access_enabled = each.value.power_access_enabled
}

