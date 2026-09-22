output "argocd_namespace" {
  description = "Namespace where Argo CD is deployed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_server_service" {
  description = "Name of the Argo CD server service"
  value       = "argocd-server"
}

output "argocd_application_name" {
  description = "Name of the bootstrapped ShopSphere Application"
  value       = "shopsphere-production"
}
