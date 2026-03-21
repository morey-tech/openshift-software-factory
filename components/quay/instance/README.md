# Quay — Instance

This folder is managed by the `operands` ApplicationSet.

## Contents

| File | Purpose |
|------|---------|
| `config.json` | Declares the target namespace (`quay-operator`) for the Argo CD Application |
| `manifests/quayregistry.yaml` | `QuayRegistry` CR — deploys the Quay container registry |

## Notes

- **Namespace:** `quay-operator` — the `QuayRegistry` CR must be deployed in the same namespace as the operator; deploying it elsewhere will cause the operator to ignore it
- **Registry name:** `registry` — the operator-generated route will be `registry-quay-quay-operator.<cluster-domain>`
- **All components operator-managed** except `mirror` (disabled — not needed, images are pushed by pipelines)
- **Clair** vulnerability scanning is enabled to feed into the Phase 6 ACS pipeline security gate
- **Object storage** is provisioned via `ObjectBucketClaim` by the NooBaa operator (ODF) — see [prerequisites](../../docs/prerequisites.md)
- **No `configBundleSecret`** — with all components managed the operator auto-generates all configuration
- See [ADR-0012](../../docs/decisions/0012-quay-registry-component-configuration.md) for the full rationale behind component choices
