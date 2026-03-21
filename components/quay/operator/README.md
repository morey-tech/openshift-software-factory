# Quay — Operator

This folder is managed by the `operators` ApplicationSet.

## Contents

| File | Purpose |
|------|---------|
| `config.json` | Declares the target namespace (`quay-operator`) for the Argo CD Application |
| `manifests/subscription.yaml` | OLM Subscription for the `quay-operator` from `redhat-operators` |
| `manifests/operator-group.yaml` | `OperatorGroup` scoped to the `quay-operator` namespace |

## Notes

- **Channel:** `stable-3.11`
- **Install plan approval:** Automatic
- **Namespace:** `quay-operator` — created automatically by Argo CD (`CreateNamespace=true`)
- **Manifests source:** Based on [redhat-cop/gitops-catalog](https://github.com/redhat-cop/gitops-catalog/tree/main/quay-operator/operator/base), copied locally with channel pinned to `stable-3.11` and namespace manifest omitted
