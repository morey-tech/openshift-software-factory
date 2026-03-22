# cert-manager — Instance

This folder is managed by the `operands` ApplicationSet.

## Contents

| File | Purpose |
|------|---------|
| `config.json` | Declares the target namespace (`cert-manager`) for the Argo CD Application |
| `manifests/cluster-issuer.yaml` | `ClusterIssuer` (`selfsigned-issuer`) for GitLab TLS certificates |
| `manifests/kustomization.yaml` | Kustomize resource list |

## Notes

- **Namespace:** `cert-manager` — created automatically by the cert-manager operator after installation; the `ClusterIssuer` is cluster-scoped and namespace is used only for Argo CD targeting
- **Dependency:** The cert-manager operator must be running before this Application syncs successfully. Argo CD will retry automatically.
- Replace `selfsigned-issuer` with an ACME or Red Hat IdM `ClusterIssuer` in Phase 4 for production-grade certificates.
