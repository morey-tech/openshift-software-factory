# OpenShift GitOps — Instance

This folder is managed by the `operands` ApplicationSet.

## Contents

| File | Purpose |
|------|---------|
| `config.json` | Declares the target namespace (`openshift-gitops`) for the Argo CD Application |
| `argocd.yaml` | ArgoCD CR (`software-factory-argocd`) — customized instance configuration |
| `cluster-role.yaml` | ClusterRole granting Argo CD full cluster management and pod exec access |

## ArgoCD Instance Configuration

The `software-factory-argocd` instance is configured with:

- **Aggregated ClusterRoles:** enabled — permissions managed via label-based aggregation
- **Kustomize:** Helm support enabled (`--enable-helm`)
- **SSO:** Dex with OpenShift OAuth integration
- **RBAC:** `cluster-admins` group mapped to `role:admin`, exec allowed for admins
- **Web terminal:** Pod exec enabled (`bash`, `sh`)
- **Route:** Server route enabled for external access
- **Resource exclusions:** Tekton `TaskRun` and `PipelineRun` resources excluded from tracking
- **HA:** Disabled (single instance)
- **Monitoring/Prometheus/Grafana:** Disabled

## Why `software-factory-argocd`?

The instance cannot be named `openshift-gitops` — that name conflicts with the default instance managed by the operator. The default instance is disabled via the operator's `DISABLE_DEFAULT_ARGOCD_INSTANCE` env var, and this custom instance is used instead.
