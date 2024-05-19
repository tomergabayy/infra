# Set up the network module
module "network" {
  source                 = "../modules/network"
  vpc_cidr               = var.vpc_cidr
  aws_availability_zones = var.aws_availability_zones
}

# Set up the EKS module
module "eks" {
  source          = "../modules/eks"
  vpc_id          = module.network.vpc_id
  private_subnets = module.network.nodes_subnet_ids
  subnet_ids      = module.network.subnet_ids
  depends_on      = [module.network]
}

# Set up the IAM OIDC module
module "iam-oidc" {
  source              = "../modules/iam-oidc"
  eks_oidc_issuer_url = module.eks.eks_oidc_issuer_url
  depends_on          = [module.network, module.eks]
}
resource "null_resource" "update_kubeconfig" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
  }
  depends_on = [module.eks]
}
module "eks-albcontroller" {
  source            = "../modules/eks-albcontroller"
  cluster_name      = module.eks.cluster_name
  cluster-endpoint  = module.eks.cluster_endpoint
  oidc-issuer       = module.eks.eks_oidc_issuer_url
  oidc-provider-arn = module.iam-oidc.oidc_arn
  config_path       = var.config_path
  depends_on = [null_resource.update_kubeconfig]
}

module "external-dns" {
  source      = "../modules/external-dns"
  oidc-arn    = module.iam-oidc.oidc_arn
  oidc-issuer = module.eks.eks_oidc_issuer_url
  depends_on  = [null_resource.update_kubeconfig]
}

module "argocd" {
  source       = "../modules/argocd-deployment"
  ROOT_PATH    = var.ROOT_PATH
  cluster-name = module.eks.cluster_name
  depends_on   = [null_resource.update_kubeconfig]
}

resource "null_resource" "argocd-init-password" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "export TF_VAR_ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath={.data.password} | base64 -d)"
  }
  depends_on = [module.argocd]
}

module "argocd-repositorys" {
  source            = "../modules/argocd-repositorys"
  argo-initial-pass = var.ARGOCD_PASS
  repo-username     = var.REPO_USERNAME
  repo-PAT          = var.HELM_REPO_PAT
  depends_on        = [null_resource.argocd-init-password]
}

module "deploy-weatherapp" {
  source    = "../modules/argo-weather-app"
  REPO_PAT  = var.HELM_REPO_PAT
  ROOT_PATH = var.ROOT_PATH
  depends_on = [module.argocd-repositorys]
}