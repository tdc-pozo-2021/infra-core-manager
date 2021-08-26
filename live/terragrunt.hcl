include {
  path = find_in_parent_folders()
}

terraform {
  source = "./"
}

inputs = {
    git_config = {
        owner = "tdc-pozo-2021"
        token = get_env("GITHUB_TOKEN")
    }

    products = [{
        name = "core-manager"
        default_tags = {}
        template_repository_enabled = false
        template_repository_name = null
        create_repo = false
        power_access_enabled = true
    }]
}