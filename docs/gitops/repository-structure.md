# GitOps Repository Structure for EKS Manifests

This document outlines the proposed Git repository structure for managing Kubernetes manifests via GitOps with ArgoCD for the n8n multi-tenant EKS environment.

## Guiding Principles

*   **Single Source of Truth**: The Git repository is the single source of truth for the desired state of all deployed applications and configurations.
*   **Declarative Configuration**: All configurations are stored declaratively as Kubernetes manifests and Kustomize overlays.
*   **Automation**: ArgoCD automates the deployment and synchronization of these manifests to the EKS cluster.
*   **Traceability and Auditability**: Git history provides a clear audit trail of all changes.
*   **Scalability**: The structure should accommodate a growing number of tenants, applications, and potentially clusters.
*   **Clarity and Organization**: Manifests should be organized logically for easy understanding and management.

## Proposed Repository Strategy: Monorepo with Kustomize

We propose a **monorepo** approach for Kubernetes manifests. This means a single Git repository will contain all configurations. Kustomize will be used extensively for managing environment-specific variations and for overlaying configurations on base manifests.

**Suggested Repository Name:** `eks-gitops-manifests` (This repository needs to be created separately).

## Proposed Directory Layout

```
eks-gitops-manifests/
├── README.md                    # Overview of the repo, conventions, ArgoCD setup pointers
├── bootstrap/                   # ArgoCD's own configuration, AppProject CRDs, root App-of-Apps
│   └── argocd/
│       ├── app-of-apps.yaml     # Root ArgoCD Application to deploy other applications/addons
│       └── projects/            # ArgoCD AppProject definitions
│           └── n8n-project.yaml # Example AppProject for n8n related apps
├── clusters/                    # Cluster-specific configurations
│   └── ${cluster_name}/         # e.g., n8n-eks-cluster-dev (matches var.cluster_name from Terraform)
│       ├── cluster-settings.yaml # Placeholder for global cluster settings managed via GitOps
│       └── system/              # Cluster-wide services / Addons (managed by ArgoCD)
│           ├── aws-load-balancer-controller/ # Example addon
│           │   ├── base/
│           │   └── overlays/
│           │       └── dev/     # Overlay for the 'dev' environment/configuration
│           ├── external-dns/
│           │   └── ...
│           └── metrics-server/
│               └── ...
├── apps/                        # Business applications and tenant instances
│   ├── _templates/              # Common Kustomize components or Helm chart value templates
│   │   └── n8n-tenant-stack/    # Kustomize component for a standard n8n tenant bundle
│   │       ├── kustomization.yaml
│   │       ├── namespace.yaml   # Base namespace definition (can be patched)
│   │       ├── n8n-helm-values.yaml # Base values for n8n Helm chart
│   │       ├── postgres-helm-values.yaml # Base values for PostgreSQL Helm chart
│   │       └── redis-helm-values.yaml    # Base values for Redis Helm chart
│   ├── n8n-internal/            # Configuration for internal n8n instances
│   │   ├── instance-a/          # Example internal instance
│   │   │   ├── base/            # Base config (e.g., uses _templates/n8n-tenant-stack)
│   │   │   │   └── kustomization.yaml
│   │   │   └── overlays/
│   │   │       └── dev/         # Dev overlay for internal instance-a
│   │   │           └── kustomization.yaml
│   │   │           └── config-patch.yaml # Specific patches for this instance
│   │   │           └── n8n-helm-values-patch.yaml # Patched Helm values
│   │   └── instance-b/
│   │       └── ...
│   ├── tenants/                 # Configurations for external (customer) tenants
│   │   ├── tenant-id-001/       # Example tenant
│   │   │   ├── base/            # Base config (e.g., uses _templates/n8n-tenant-stack)
│   │   │   │   └── kustomization.yaml
│   │   │   └── overlays/
│   │   │       └── prod/        # Prod overlay for tenant-id-001
│   │   │           └── kustomization.yaml
│   │   │           └── namespace-prod.yaml # Specific namespace for prod tenant
│   │   │           └── config-patch.yaml   # Tenant-specific configurations
│   │   │           └── n8n-helm-values-prod.yaml # Tenant-specific Helm values
│   │   ├── tenant-id-002/
│   │   │   └── ...
│   │   └── _new_tenant_template/ # Template directory for onboarding new tenants
│   │       ├── base/
│   │       │   └── kustomization.yaml
│   │       └── overlays/
│   │           └── prod/ # Or a generic 'env' overlay
│   │               └── kustomization.yaml
│   │               └── namespace-template.yaml
│   │               └── helm-values-template.yaml
└── lib/                         # (Optional) Shared Kustomize patches or components
    └── common-labels.yaml
```

### Directory Explanations:

*   **`README.md`**: Provides an overview of this repository, contribution guidelines, and how it relates to ArgoCD.
*   **`bootstrap/argocd/`**:
    *   `app-of-apps.yaml`: A root ArgoCD `Application` that manages other ArgoCD `Application` resources. This allows you to manage your entire suite of applications and addons declaratively.
    *   `projects/`: Defines ArgoCD `AppProject` CRDs. Projects provide logical grouping for applications and control what can be deployed where (destination clusters/namespaces) and from which Git repositories.
*   **`clusters/${cluster_name}/`**:
    *   This directory holds configurations that are specific to a particular Kubernetes cluster. The `${cluster_name}` should match the name of your EKS cluster (e.g., `n8n-eks-cluster-dev`).
    *   `system/`: For cluster-level addons or services that are deployed via GitOps after the cluster is up (e.g., ingress controllers, monitoring tools, logging agents). Each addon can have its own `base` and `overlays` for environment-specific configurations if needed.
        *   **Note**: Core infrastructure components like the EKS cluster itself, VPC, Karpenter, and ArgoCD are bootstrapped via Terraform. This `system/` directory is for addons managed *by* ArgoCD.
*   **`apps/`**:
    *   `_templates/n8n-tenant-stack/`: This is a crucial Kustomize component. It should define the common set of resources for an n8n tenant (n8n deployment/StatefulSet, PostgreSQL StatefulSet/service, Redis deployment/service). It would typically reference the Helm charts for n8n, PostgreSQL, and Redis, and include base `values.yaml` files.
    *   `n8n-internal/`: Houses configurations for internal n8n instances. Each instance has a `base` (which references the `_templates/n8n-tenant-stack/`) and an `overlays/dev/` (or other environments) directory for specific patches (e.g., resource requests/limits, specific configurations, different database connection strings if not using per-tenant DBs for internal instances).
    *   `tenants/`: For external customer tenants. Each tenant gets its own directory.
        *   The `base/` for each tenant would also use the `_templates/n8n-tenant-stack/` Kustomize component.
        *   `overlays/prod/` (or the relevant environment) would contain Kustomize patches for tenant-specific settings:
            *   Namespace definition.
            *   Resource quotas and limit ranges.
            *   Network policies.
            *   Secrets for database credentials (ideally managed through a secrets operator like External Secrets Operator (ESO) or HashiCorp Vault, referenced by Kubernetes `Secret` manifests which ESO would then populate).
            *   Tenant-specific n8n Helm values (e.g., license keys, custom branding, resource allocations).
    *   `_new_tenant_template/`: A starting point that can be copied and customized when onboarding a new tenant.
*   **`lib/`**: (Optional) For reusable Kustomize patches or components, like a common set of labels or annotations to be applied everywhere.

## Integration with ArgoCD

*   **AppProjects**: Define `AppProject` CRDs in `bootstrap/argocd/projects/` to group applications (e.g., an "n8n-tenants" project, an "n8n-internal" project, a "cluster-system" project). Projects enforce restrictions on source repos, destination clusters/namespaces, and permitted resource kinds.
*   **Applications**:
    *   ArgoCD `Application` CRDs will point to specific paths within this repository. For example:
        *   An ArgoCD App for `tenant-id-001` might have `spec.source.path: apps/tenants/tenant-id-001/overlays/prod`.
        *   An ArgoCD App for an internal n8n instance might have `spec.source.path: apps/n8n-internal/instance-a/overlays/dev`.
        *   An ArgoCD App for a cluster addon might have `spec.source.path: clusters/n8n-eks-cluster-dev/system/aws-load-balancer-controller/overlays/dev`.
    *   These `Application` CRDs can themselves be managed in Git, often via an "App of Apps" pattern defined in `bootstrap/argocd/app-of-apps.yaml`.
*   **Kustomize & Helm**: ArgoCD natively supports Kustomize. For Helm charts, you can either:
    1.  Let ArgoCD directly manage Helm charts and provide environment-specific values files from this Git repo.
    2.  Use Kustomize to manage Helm chart deployments (e.g., using `helmCharts` field in `kustomization.yaml` or by Kustomizing Helm chart output). This provides more flexibility for patching Helm chart outputs if needed. The `_templates/n8n-tenant-stack/` could use this approach.

## Branching Strategy

*   **Trunk-Based Development**: A single `main` branch is recommended as the source of truth.
*   All changes, including new tenant onboarding or configuration updates, are made via Pull Requests (PRs) to the `main` branch.
*   This promotes a clear history and allows for reviews and automated checks before changes are applied to the cluster(s) by ArgoCD.

## Workflow Example (New Tenant Onboarding)

1.  Copy the `apps/tenants/_new_tenant_template/` directory to `apps/tenants/new-tenant-id/`.
2.  Customize the Kustomize overlays in `apps/tenants/new-tenant-id/overlays/prod/` (e.g., update namespace, resource limits, Helm values for database connection, n8n specific settings).
3.  (If using App-of-Apps) Add a new ArgoCD `Application` definition to your App-of-Apps manifest, pointing to the new tenant's path.
4.  Commit changes to a new feature branch and create a PR to `main`.
5.  Upon review and merge, ArgoCD will detect the changes (either to an existing Application CRD it tracks or a new one if using App-of-Apps) and deploy the new tenant's resources.

This structure provides a solid foundation for managing your EKS deployments with GitOps, supporting multi-tenancy and environment-specific configurations effectively.
