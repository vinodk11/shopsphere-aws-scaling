# ==============================================================================
# Argo CD Installation & Bootstrap Module (Stage 10 GitOps)
# ==============================================================================

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "stage"                        = "stage-10"
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  timeout    = 600

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }

  set {
    name  = "controller.enableStatefulSet"
    value = "false"
  }

  set {
    name  = "dex.enabled"
    value = "false"
  }

  set {
    name  = "notifications.enabled"
    value = "false"
  }

  depends_on = [kubernetes_namespace.argocd]
}

# ------------------------------------------------------------------------------
# Argo CD AppProject and Application Bootstrap
# ------------------------------------------------------------------------------
resource "kubernetes_manifest" "argocd_project" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "shopsphere"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      labels = {
        stage = "stage-10"
      }
    }
    spec = {
      description = "ShopSphere Stage 10 Enterprise GitOps Project"
      sourceRepos = [
        var.gitops_repo_url,
        "*"
      ]
      destinations = [
        {
          namespace = "shopsphere-stage9"
          server    = "https://kubernetes.default.svc"
        },
        {
          namespace = "argocd"
          server    = "https://kubernetes.default.svc"
        }
      ]
      clusterResourceWhitelist = [
        {
          group = ""
          kind  = "Namespace"
        },
        {
          group = "elbv2.k8s.aws"
          kind  = "TargetGroupBinding"
        }
      ]
      namespaceResourceWhitelist = [
        {
          group = "*"
          kind  = "*"
        }
      ]
    }
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_manifest" "argocd_application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "shopsphere-production"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      labels = {
        app   = "shopsphere"
        stage = "stage-10"
      }
    }
    spec = {
      project = "shopsphere"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_branch
        path           = var.gitops_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "shopsphere-stage9"
      }
      syncPolicy = {
        automated = {
          prune    = false
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "ApplyOutOfSyncOnly=true"
        ]
        retry = {
          limit = 5
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "1m"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.argocd_project]
}
