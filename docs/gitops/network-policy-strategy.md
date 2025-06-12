# Kubernetes Network Policy Strategy for Multi-Tenancy

This document outlines the strategy for using Kubernetes NetworkPolicies to enforce network traffic rules for tenant isolation in the n8n multi-tenant EKS environment. It includes standard manifest templates that serve as a baseline for configuring network access for each tenant's namespace.

## Guiding Principles

*   **Default Deny**: Each tenant namespace will operate under a default-deny posture for all ingress and egress network traffic.
*   **Explicit Allow**: Only explicitly defined communication paths will be permitted through allow-rules.
*   **Tenant Isolation**: Prevent any direct network communication between different tenant namespaces unless explicitly configured for a shared service (which is not the default model for n8n tenants).
*   **Least Privilege**: Network policies should grant only the necessary network access for the n8n application stack and its legitimate external communications.
*   **GitOps Managed**: All NetworkPolicy manifests will be declaratively defined in the `eks-gitops-manifests` Git repository and applied by ArgoCD.

## Prerequisites

*   An EKS cluster with a CNI plugin that supports NetworkPolicy enforcement (Amazon VPC CNI is used by default in EKS and supports this).
*   A defined namespace-per-tenant strategy (as per EKS-TASK-008).
*   Consistent labeling of pods within each tenant's n8n stack (e.g., via the `n8n-tenant-stack` Helm chart) to allow for effective `podSelector` usage.

## Standard Network Policy Templates

The following YAML templates provide a baseline for securing a tenant's namespace. These would typically be stored in the GitOps repository (e.g., under `apps/tenants/<tenant-id>/base/network-policies/` or similar) and applied by ArgoCD. Placeholders like `{{ .Tenant.Namespace }}`, `{{ .Chart.Name }}`, and `{{ .Values... }}` indicate values that would be dynamically substituted by Kustomize, ArgoCD parameter overrides, or by being concretely defined in per-tenant manifest files.

---

### 1. Default Deny All (`default-deny-all.yaml`)

This policy is the foundation, blocking all ingress and egress traffic for all pods in the target namespace by default.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  # This policy should be applied to each tenant's namespace.
  # The namespace will be set by the Kustomize overlay or ArgoCD application definition.
  # namespace: {{ .Tenant.Namespace }}
spec:
  podSelector: {} # Selects all pods in the namespace
  policyTypes:
  - Ingress
  - Egress
  # No ingress or egress rules defined, meaning all traffic is denied by default.
```

---

### 2. Allow DNS Egress (`allow-dns-egress.yaml`)

Allows all pods in the namespace to resolve DNS queries via CoreDNS in `kube-system`.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  # namespace: {{ .Tenant.Namespace }}
spec:
  podSelector: {} # Apply to all pods
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          # For EKS, CoreDNS is in kube-system.
          # Using the immutable namespace name label for reliability.
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns # Standard label for CoreDNS pods
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

---

### 3. Allow Intra-Namespace Communication (`allow-intra-namespace.yaml`)

Allows pods within the same namespace (belonging to the n8n tenant stack) to communicate freely with each other. More granular policies can be created if needed.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-intra-namespace
  # namespace: {{ .Tenant.Namespace }}
spec:
  podSelector: {} # This policy applies to all pods in the namespace
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {} # Allow traffic from any other pod within the same namespace
  # Egress within the namespace is implicitly allowed if no specific egress rules block it
  # after the default-deny is in place and other egress (like DNS) is allowed.
  # For explicit control, an egress rule allowing to podSelector: {} could be added.
```
*Note: For a stricter setup, one could define specific ingress rules for each component (n8n-main, postgres, redis) allowing traffic only from other specific components within the namespace on their required ports.*

---

### 4. Allow Ingress to n8n UI/API (`allow-n8n-ingress.yaml`)

Allows external access to the n8n main service (UI/API).

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-n8n-ingress
  # namespace: {{ .Tenant.Namespace }}
spec:
  # Selects the n8n main pods based on labels from the Helm chart
  podSelector:
    matchLabels:
      app.kubernetes.io/name: {{ .Chart.Name }}
      app.kubernetes.io/component: n8n-main
  policyTypes:
  - Ingress
  ingress:
  - from:
    # Option 1: Allow from Ingress Controller's Namespace(s)
    # This requires knowing the namespace and pod labels of your Ingress controller.
    - namespaceSelector:
        matchLabels:
          # Example for AWS Load Balancer Controller if its pods are in kube-system
          # and have a specific label. Adjust as per your Ingress controller setup.
          kubernetes.io/metadata.name: kube-system
      # podSelector:
      #   matchLabels:
      #     app.kubernetes.io/name: aws-load-balancer-controller # Example
    # Option 2: Allow from specific IP Blocks (if using Service type LoadBalancer directly)
    # - ipBlock:
    #     cidr: "YOUR_OFFICE_IP/32" # Restrict to known IPs
    #     # For general access via a LoadBalancer, you might allow 0.0.0.0/0,
    #     # but this should be carefully considered.
    ports:
    # This should match the port your n8n main service listens on (e.g., 5678)
    - protocol: TCP
      port: {{ .Values.n8n.main.service.port | default 5678 }}
```

---

### 5. Allow Egress to Internet (for n8n Workflows) (`allow-internet-egress.yaml`)

Allows n8n pods (main and workers) to make outbound connections to the internet (e.g., for accessing third-party APIs).

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-internet-egress-n8n
  # namespace: {{ .Tenant.Namespace }}
spec:
  # Selects n8n main and worker pods
  podSelector:
    matchLabels:
      app.kubernetes.io/name: {{ .Chart.Name }}
      # This could be refined if only workers need broad egress,
      # or if main needs it for certain triggers/initial calls.
      # For simplicity, targeting all app pods initially.
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0 # Allows egress to all IPs
        except:
          # Block access to private RFC1918 ranges to prevent accidental
          # access to other internal VPC resources or other tenant networks
          # if not routed through a NAT Gateway that handles this.
          - 10.0.0.0/8
          - 172.16.0.0/12
          - 192.168.0.0/16
    ports: # Typically, workflows will access external APIs over HTTPS or HTTP
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
  # Note: This is a relatively broad egress rule. For higher security,
  # if the set of external IPs/domains n8n needs to access is known and limited,
  # this should be restricted further. However, n8n's dynamic nature often
  # makes this challenging. Using a proxy/gateway for egress filtering could be
  # an advanced option.
```

## Application Strategy

For each tenant namespace:
1.  Apply `default-deny-all.yaml`.
2.  Apply `allow-dns-egress.yaml`.
3.  Apply `allow-intra-namespace.yaml` (ensure pod selectors match the labels used by your n8n Helm chart for its components).
4.  Apply `allow-n8n-ingress.yaml` (configure `namespaceSelector` or `ipBlock` based on how n8n is exposed - Ingress controller or LoadBalancer service).
5.  Apply `allow-internet-egress.yaml` (consider the security implications of the chosen egress strategy).

These policies should be stored in the GitOps repository under each tenant's configuration path and managed by ArgoCD.

## Internal vs. External Instance Isolation

The above templates provide a baseline. For differentiating between "internal" and "external" n8n instances:
*   **Separate Kustomize Overlays**: Maintain different Kustomize overlays for internal vs. external tenant types. These overlays can apply different versions of the egress policies or add/remove specific allow rules.
*   **Namespace Labels**: Use distinct labels on namespaces for internal vs. external tenants (e.g., `tenant-type: internal` vs. `tenant-type: external`). Network policies can then use `namespaceSelector` to apply different rules based on these labels, although this is more for policies *between* namespaces rather than policies *within* them. The primary differentiation for internal/external within their own namespace would be achieved by applying tailored versions of the egress policies.

## Testing and Validation (Conceptual)

*   **Connectivity Matrix**: Define a matrix of expected allowed/denied connections (pod-to-pod within namespace, pod-to-external, external-to-pod).
*   **Tools**: Use tools like `kubectl exec` into pods and run `curl`, `nc`, or `ping` (if ICMP is allowed by CNI/policies) to test connectivity.
*   **Verify Default Deny**: Ensure no traffic flows before specific allow policies are applied.
*   **Validate Allow Rules**: Check each explicitly allowed path.
*   **Inter-Tenant Test**: Attempt connections from a pod in Tenant A's namespace to a pod or service in Tenant B's namespace (should be denied).

This Network Policy strategy provides a strong foundation for securing tenant workloads within the EKS cluster.
