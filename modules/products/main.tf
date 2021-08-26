locals {
  webhook-secret = random_id.webhook-secret.b64_std
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_codestarconnections_connection" "main" {
  name          = "${var.name}-connection"
  provider_type = "GitHub"
}

resource "github_repository" "example" {
  count = var.create_repo ? 1 : 0
  name        = "infra-${var.name}"
  description = "Managed by Terraform."

  visibility = "public"

  dynamic "template" {
    for_each = var.template_repository_enabled ? [1] : []
    content {
      owner      = var.git_config.owner
      repository = var.template_repository_name
    }
  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "code-pipeline-artifacts-${var.name}-${data.aws_region.current.name}"
  acl    = "private"
}

resource "aws_iam_role" "code-build-role" {
  name                 = "AWSCodeBuildServiceRole-tdc-${var.name}-${data.aws_region.current.name}"
  path                 = "/service-role/"
  max_session_duration = 3600
  assume_role_policy   = <<ASSUME_ROLE_POLICY
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Effect": "Allow",
          "Principal": {
              "Service": "codebuild.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
      }
  ]
}
ASSUME_ROLE_POLICY
}


resource "aws_iam_policy" "power-access-policy" {
  count = var.power_access_enabled ? 1 : 0
  name   = "AWSPowerAccess-tdc-${var.name}"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "power-access-attach" {
  count = var.power_access_enabled ? 1 : 0

  role       = aws_iam_role.code-build-role.name
  policy_arn = aws_iam_policy.power-access-policy[0].arn
}


resource "aws_codebuild_project" "main" {
  name         = "${var.name}-codebuild-project"
  service_role = aws_iam_role.code-build-role.arn

  artifacts {
    name = "${var.name}-artifacts"
    type = "CODEPIPELINE"
  }

  source {
    buildspec           = "buildspec.yaml"
    type                = "CODEPIPELINE"
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
  }

  environment {
    image                       = "aws/codebuild/standard:3.0"
    image_pull_credentials_type = "CODEBUILD"
    compute_type                = "BUILD_GENERAL1_SMALL"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true

    environment_variable {
      name  = "TF_VAR_github_token"
      value = var.git_config.token
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/BaseInfraProvider-build"
      status     = "ENABLED"
    }
  }

  depends_on = [aws_iam_role.code-build-role]
}

resource "aws_codepipeline" "main" {
  name     = var.name
  role_arn = aws_iam_role.assume-codepipeline-role.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifacts.id
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.main.arn
        BranchName           = "master"
        FullRepositoryId    = "${var.git_config.owner}/infra-${var.name}"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      configuration = {
        ProjectName = "${var.name}-codebuild-project"
      }
    }
  }

  tags       = var.default_tags
  depends_on = [aws_iam_role.assume-codepipeline-role]
}

resource "aws_codepipeline_webhook" "codepipeline-webhook" {
  name            = "${aws_codepipeline.main.name}-Source-${var.git_config.owner}-${aws_codepipeline.main.name}--${random_integer.webhook-suffix.result}"
  target_pipeline = aws_codepipeline.main.name
  target_action   = "Source"
  authentication  = "GITHUB_HMAC"

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/master"
  }

  authentication_configuration {
    secret_token = local.webhook-secret
  }
}


resource "github_repository_webhook" "github-webhook" {
  repository = "infra-${var.name}"

  configuration {
    url          = aws_codepipeline_webhook.codepipeline-webhook.url
    content_type = "json"
    insecure_ssl = false
    secret       = local.webhook-secret
  }

  events = ["push"]
}

resource "aws_iam_role" "assume-codepipeline-role" {
  name               = "AWSCodePipeline-tdc-${var.name}-${data.aws_region.current.name}"
  path               = "/service-role/"
  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "codepipeline.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
POLICY
}

resource "aws_iam_policy" "codebuild-start-get-policy" {
  name   = "AWSCodePipelineStartBuildPolicy-tdc-${var.name}-${data.aws_region.current.name}"
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": "${aws_iam_role.code-build-role.arn}",
            "Action": [
                "codebuild:BatchGetBuilds",
                "codebuild:StartBuild"
            ]
        },
        {
            "Effect": "Allow",
            "Resource": "${aws_codestarconnections_connection.main.arn}",
            "Action": [
                "codestar-connections:UseConnection"
            ]
        }
    ]
}
POLICY
}

resource "aws_iam_policy" "access-artifacts-bucket-policy" {
  name   = "AWSCodePipelineAccessArtifactsBucketPolicy-tdc-${var.name}-${data.aws_region.current.name}"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "${aws_s3_bucket.artifacts.arn}"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "${aws_s3_bucket.artifacts.arn}/*"
    }
  ]
}
POLICY
}


resource "aws_iam_role_policy_attachment" "access-artifacts-bucket-attach" {
  role       = aws_iam_role.assume-codepipeline-role.name
  policy_arn = aws_iam_policy.access-artifacts-bucket-policy.arn
}

resource "aws_iam_role_policy_attachment" "codebuild-policy-attach" {
  role       = aws_iam_role.assume-codepipeline-role.name
  policy_arn = aws_iam_policy.codebuild-start-get-policy.arn
}

resource "random_id" "webhook-secret" {
  byte_length = 30

  keepers = {
    webhook-secret = aws_codepipeline.main.name
  }
}

resource "random_integer" "webhook-suffix" {
  min = 1000000000
  max = 9999999999

  keepers = {
    webhook-suffix = aws_codepipeline.main.name
  }
}