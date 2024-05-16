resource "argocd_repository" "private" {
  repo            = "https://github.com/tomergabayy/gitops-config.git"
  username        = var.repo-username
  password        = var.repo-PAT
  insecure        = true
  type            = "git"
}