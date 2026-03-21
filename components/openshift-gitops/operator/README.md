# OpenShift GitOps — Operator

This folder is managed by the `operators` ApplicationSet.

## Contents

| File | Purpose |
|------|---------|
| `config.json` | Declares the target namespace (`openshift-gitops-operator`) for the Argo CD Application |
| `manifests/operator-group.yaml` | OperatorGroup scoped to `openshift-gitops-operator` namespace |
| `manifests/subscription.yaml` | OLM Subscription for `openshift-gitops-operator` from `redhat-operators` |

## Notes

- **Channel:** `latest`
- **Install plan approval:** Automatic
- **Namespace:** Dedicated `openshift-gitops-operator` namespace (not `openshift-operators`) — requires its own OperatorGroup
- **Default instance disabled:** `DISABLE_DEFAULT_ARGOCD_INSTANCE=true` — the ArgoCD instance is managed separately in `instance/`
