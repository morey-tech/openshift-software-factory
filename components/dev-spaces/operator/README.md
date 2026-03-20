# Dev Spaces — Operator

This folder is managed by the `operators` ApplicationSet.

## Contents

| File | Purpose |
|------|---------|
| `config.json` | Declares the target namespace (`openshift-operators`) for the Argo CD Application |
| `subscription.yaml` | OLM Subscription for the `devspaces` operator from `redhat-operators` |

## Notes

- **Channel:** `stable`
- **Install plan approval:** Automatic
- **Namespace:** Installs into `openshift-operators` (global operator namespace) — no OperatorGroup needed
