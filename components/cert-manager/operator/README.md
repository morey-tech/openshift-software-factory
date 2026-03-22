# cert-manager — Operator

This folder is managed by the `operators` ApplicationSet.

## Contents

| File | Purpose |
|------|---------|
| `config.json` | Declares the target namespace (`cert-manager-operator`) for the Argo CD Application |
| `manifests/subscription.yaml` | OLM Subscription for `openshift-cert-manager-operator` from `redhat-operators` |
| `manifests/operator-group.yaml` | `OperatorGroup` scoped to the `cert-manager-operator` namespace |

## Notes

- **Channel:** `stable-v1`
- **Install plan approval:** Automatic
- **Namespace:** `cert-manager-operator` — the operator runs here; cert-manager controllers run in `cert-manager` (created automatically by the operator)
