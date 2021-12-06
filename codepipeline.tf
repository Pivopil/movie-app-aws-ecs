provider "github" {}

data "aws_iam_policy_document" "codepipeline_role_document" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name = "${var.prefix}-codepipeline_role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_role_document.json
}

data "aws_iam_policy_document" "codepipeline_policy_document" {
  version = "2012-10-17"
  statement {
    actions = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject",
    "s3:GetBucketVersioning"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.artifact_bucket.arn}/*"]
  }
  statement {
    actions = ["codebuild:StartBuild", "codebuild:BatchGetBuilds",
      "cloudformation:*",
    "iam:PassRole"]
    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    actions   = ["ecs:*"]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_policy" "codepipeline_policy" {
  description = "Policy to allow codepipeline to execute"
  policy      = data.aws_iam_policy_document.codepipeline_policy_document.json
}

resource "aws_iam_role_policy_attachment" "codepipeline-attach" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}

resource "aws_codepipeline" "pipeline" {
  depends_on = [
    aws_codebuild_project.codebuild,
  ]
  name     = "${var.prefix}-Pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  artifact_store {
    location = aws_s3_bucket.artifact_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      version          = "1"
      provider         = "GitHub"
      output_artifacts = ["SourceOutput"] # code
      run_order        = 1
      configuration = {
        Owner                = var.repo_owner
        Repo                 = var.repo_name
        Branch               = var.branch
        OAuthToken           = var.github_oauth_token
        PollForSourceChanges = "false"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      version          = "1"
      provider         = "CodeBuild"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]
      run_order        = 1
      configuration = {
        ProjectName = aws_codebuild_project.codebuild.id
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      version         = "1"
      provider        = "ECS"
      run_order       = 1
      input_artifacts = ["BuildOutput"]
      configuration = {
        ClusterName       = aws_ecs_cluster.fargate_cluster.name
        ServiceName       = var.ecs_service_name
        FileName          = "imagedefinitions.json"
        DeploymentTimeout = "15"
      }
    }
  }
  lifecycle {
    # prevent github OAuthToken from causing updates, since it's removed from state file
    ignore_changes = [stage[0].action[0].configuration.OAuthToken]
  }
}

resource "aws_codepipeline_webhook" "bar" {
  name            = "${var.prefix}-webhook-github-bar"
  authentication  = "GITHUB_HMAC"
  target_action   = "Source"
  target_pipeline = aws_codepipeline.pipeline.name

  authentication_configuration {
    secret_token = var.webhook_secret
  }

  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/{Branch}"
  }
}

resource "github_repository_webhook" "bar" {
  repository = var.repo_name

  configuration {
    url          = aws_codepipeline_webhook.bar.url
    content_type = "json"
    insecure_ssl = true
    secret       = var.webhook_secret
  }

  events = ["push"]
}

output "pipeline_url" {
  value = "https://console.aws.amazon.com/codepipeline/home?region=${data.aws_region.current.id}#/view/${aws_codepipeline.pipeline.id}"
}

variable "github_oauth_token" {
}

variable "repo_owner" {
}

variable "repo_name" {
}

variable "branch" {
}

variable "webhook_secret" {
}

