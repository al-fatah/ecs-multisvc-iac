data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# If your account doesn't already have the provider, uncomment this and apply once:
# resource "aws_iam_openid_connect_provider" "github" {
#   url             = "https://token.actions.githubusercontent.com"
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
# }

# Role for Terraform workflows (IaC repo)
data "aws_iam_policy_document" "gha_assume_iac" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_repo_iac}:ref:refs/heads/main",
        "repo:${var.github_org}/${var.github_repo_iac}:pull_request"
      ]
    }
  }
}

resource "aws_iam_role" "gha_iac" {
  name               = "${local.name}-gha-terraform"
  assume_role_policy = data.aws_iam_policy_document.gha_assume_iac.json
}

# Minimal permissions for demo (portfolio)
# You can tighten later; for now allow Terraform to manage the resources you created.
resource "aws_iam_role_policy_attachment" "gha_iac_admin" {
  role       = aws_iam_role.gha_iac.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
