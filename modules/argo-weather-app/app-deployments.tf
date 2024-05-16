resource "helm_release" "weatherapp" {
  name       = "application"
  repository = "https://${var.REPO_PAT}@github.com/bensh199/WeatherApp-Helm"
  chart      = "${var.ROOT_PATH}/WeatherApp-Helm/WeatherApp-argocdApp/app"
  version    = "0.1.0"
  namespace = "argocd"
}