# Kubernetes Namespace Strategy for Multi-Tenancy

This document outlines the strategy for using Kubernetes namespaces to achieve tenant isolation in the n8n multi-tenant EKS environment. It includes standard manifest templates for setting up a new tenant's namespace with appropriate RBAC and resource policies.

## Guiding Principles

*   **Namespace per Tenant**: Each tenant (including internal n8n instances if treated as distinct tenants) will operate within its own dedicated Kubernetes namespace. This is a fundamental boundary for isolation.
*   **Least Privilege**: RBAC policies will grant workloads only the permissions necessary for their operation within their namespace.
*   **Resource Management**: ResourceQuotas and LimitRanges will be applied per namespace to ensure fair resource distribution and prevent noisy neighbor issues.
*   **GitOps Managed**: Namespace configurations, including RBAC and resource policies, will be declaratively defined as YAML manifests and managed in the `eks-gitops-manifests` Git repository, applied by ArgoCD.

## Standard Manifest Templates

The following templates serve as a baseline for creating a new tenant's namespace and its associated policies. These would typically be placed under a tenant-specific path in the GitOps repository (e.g., `apps/tenants/<tenant-id>/base/` or `apps/tenants/<tenant-id>/overlays/<env>/`) and customized as needed using Kustomize or parameters via ArgoCD Application generators.

Placeholders like `{{ .Tenant.ID }}`, `{{ .Environment }}`, `{{ .ArgoCD.AppName }}`, `{{ .RBAC.ServiceAccountName }}`, `{{ .QuotaConfig.LimitsCpu }}`, etc., are used to indicate values that would be dynamically inserted or patched based on the specific tenant and environment.

---

### 1. Namespace Manifest (`namespace.yaml`)

This manifest defines the dedicated namespace for a tenant.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  # Name should be unique and tenant-specific, e.g., n8n-tenant-alpha-prod
  name: {{ .Tenant.ID }}-{{ .Environment }}
  labels:
    # Label to indicate management by ArgoCD (replace with actual ArgoCD app name if applicable)
    argocd.argoproj.io/managed-by: {{ .ArgoCD.AppName | default "unknown-argocd-app" }}
    # Custom labels for easier selection and policy enforcement
    tenant-id: "{{ .Tenant.ID }}"
    environment: "{{ .Environment }}"
    # Example: tier: "{{ .Tenant.Tier | default "standard" }}"
```

---

### 2. Default RBAC Role (`default-role.yaml`)

This Role defines permissions for n8n workloads within the tenant's namespace.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: {{ .Tenant.ID }}-{{ .Environment }} # Target tenant namespace
  name: n8n-tenant-default-role
  labels:
    tenant-id: "{{ .Tenant.ID }}"
rules:
- apiGroups: [""] # Core API group
  resources:
  - pods
  - services
  - endpoints
  - persistentvolumeclaims
  - configmaps
  - secrets
  - serviceaccounts
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
  - deletecollection # Added for some controllers
- apiGroups: ["apps"]
  resources:
  - deployments
  - statefulsets
  - replicasets
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
- apiGroups: ["batch"]
  resources:
  - jobs
  - cronjobs
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
- apiGroups: ["networking.k8s.io"]
  resources:
  - ingresses # If n8n needs to manage its own Ingress rules within its namespace
  # - networkpolicies # Consider managing NetworkPolicies at a higher level or with more specific roles
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
# Add other specific permissions as required by n8n or its sub-components (e.g., specific CRDs).
# Permissions for n8n's own CRDs (if any) might also be needed if it manages them.
```

---

### 3. Default RBAC RoleBinding (`default-rolebinding.yaml`)

This RoleBinding links the `n8n-tenant-default-role` to a ServiceAccount that n8n pods will use.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: n8n-tenant-default-binding
  namespace: {{ .Tenant.ID }}-{{ .Environment }} # Target tenant namespace
  labels:
    tenant-id: "{{ .Tenant.ID }}"
subjects:
- kind: ServiceAccount
  # This should match the ServiceAccount name used by the n8n Helm chart deployment for this tenant.
  name: {{ .RBAC.ServiceAccountName | default "n8n-tenant-default-sa" }}
  namespace: {{ .Tenant.ID }}-{{ .Environment }} # Explicitly state namespace for subject
roleRef:
  kind: Role
  name: n8n-tenant-default-role # Refers to the Role created above
  apiGroup: rbac.authorization.k8s.io
```
*Note: The n8n Helm chart should be configured to use or create a ServiceAccount with the name specified in `subjects[0].name`.*

---

### 4. Default ResourceQuota (`default-resourcequota.yaml`)

This ResourceQuota defines resource limits for the tenant namespace. These are examples and should be adjusted based on tenant tiers and available cluster capacity.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: n8n-tenant-default-quota
  namespace: {{ .Tenant.ID }}-{{ .Environment }} # Target tenant namespace
  labels:
    tenant-id: "{{ .Tenant.ID }}"
spec:
  hard:
    # CPU and Memory Quotas
    limits.cpu: "{{ .QuotaConfig.LimitsCpu | default "4" }}"
    limits.memory: "{{ .QuotaConfig.LimitsMemory | default "8Gi" }}"
    requests.cpu: "{{ .QuotaConfig.RequestsCpu | default "2" }}"
    requests.memory: "{{ .QuotaConfig.RequestsMemory | default "4Gi" }}"

    # Storage Quotas
    requests.storage: "{{ .QuotaConfig.RequestsStorage | default "50Gi" }}" # Total storage for all PVCs
    persistentvolumeclaims: "{{ .QuotaConfig.PersistentVolumeClaims | default "10" }}" # Max number of PVCs

    # Object Count Quotas
    count/pods: "{{ .QuotaConfig.CountPods | default "50" }}"
    count/services: "{{ .QuotaConfig.CountServices | default "20" }}"
    count/configmaps: "{{ .QuotaConfig.CountConfigmaps | default "50" }}"
    count/secrets: "{{ .QuotaConfig.CountSecrets | default "50" }}"
    count/deployments.apps: "{{ .QuotaConfig.CountDeployments | default "10" }}"
    count/statefulsets.apps: "{{ .QuotaConfig.CountStatefulsets | default "10" }}"
```

---

### 5. Default LimitRange (`default-limitrange.yaml`)

This LimitRange defines default resource requests and limits for containers within the namespace if not specified by the pod spec.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: n8n-tenant-default-limits
  namespace: {{ .Tenant.ID }}-{{ .Environment }} # Target tenant namespace
  labels:
    tenant-id: "{{ .Tenant.ID }}"
spec:
  limits:
  - type: Container
    max: # Maximum resources a single container can request
      cpu: "{{ .LimitRangeConfig.ContainerMaxCpu | default "2" }}"
      memory: "{{ .LimitRangeConfig.ContainerMaxMemory | default "4Gi" }}"
    min: # Minimum resources a single container must request
      cpu: "{{ .LimitRangeConfig.ContainerMinCpu | default "100m" }}"
      memory: "{{ .LimitRangeConfig.ContainerMinMemory | default "128Mi" }}"
    default: # Default limits applied to containers if not specified
      cpu: "{{ .LimitRangeConfig.ContainerDefaultCpu | default "500m" }}"
      memory: "{{ .LimitRangeConfig.ContainerDefaultMemory | default "512Mi" }}"
    defaultRequest: # Default requests applied to containers if not specified
      cpu: "{{ .LimitRangeConfig.ContainerDefaultRequestCpu | default "200m" }}"
      memory: "{{ .LimitRangeConfig.ContainerDefaultRequestMemory | default "256Mi" }}"
```

## Management and Customization

*   **GitOps Repository**: These templates (or concrete versions derived from them) will reside in the `eks-gitops-manifests` repository, typically under a path structure like `apps/tenants/<tenant-id>/base/` for base configurations and `apps/tenants/<tenant-id>/overlays/<environment>/` for environment-specific patches.
*   **ArgoCD**: ArgoCD Applications will be configured to point to these paths. The `AppProject` CRD can be used to govern what these applications can deploy and where.
*   **Customization**:
    *   **Kustomize**: Use Kustomize overlays to patch these defaults for specific tenants (e.g., increase `ResourceQuota` for a premium tenant, add specific labels).
    *   **ArgoCD Application Parameters**: If using ArgoCD ApplicationSet generators, parameters can be injected into these templates to customize them per tenant.
*   **Service Account**: Ensure the n8n Helm chart (from EKS-TASK-006) is configured to use the ServiceAccount named in the `RoleBinding` (e.g., `n8n-tenant-default-sa` or a tenant-specific SA name). The Helm chart might create its own SA, in which case the RoleBinding subject needs to match that.

This namespace strategy, combined with Network Policies (EKS-TASK-009) and IRSA for AWS resources (EKS-TASK-010), will form the core of the multi-tenant isolation model.
