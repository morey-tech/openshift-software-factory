# OpenShift GitOps — Operator

This folder is managed by the `operators` ApplicationSet.

## Contents

| File | Purpose |
|------|---------|
| `namespace.yaml` | Creates the `openshift-gitops-operator` namespace |
| `operator-group.yaml` | OperatorGroup scoped to `openshift-gitops-operator` namespace |
| `subscription.yaml` | OLM Subscription for `openshift-gitops-operator` from `redhat-operators` |

## Notes

- **Channel:** `latest`
- **Install plan approval:** Automatic
- **Namespace:** Dedicated `openshift-gitops-operator` namespace (not `openshift-operators`) — requires its own OperatorGroup
- **Default instance disabled:** `DISABLE_DEFAULT_ARGOCD_INSTANCE=true` — the ArgoCD instance is managed separately in `instance/`
