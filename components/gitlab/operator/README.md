# GitLab — Operator

This folder is managed by the `operators` ApplicationSet.

## Contents

| File | Purpose |
|------|---------|
| `config.json` | Declares the target namespace (`gitlab-system`) for the Argo CD Application |
| `manifests/catalog-source.yaml` | Custom `CatalogSource` for the OperatorHub.io community catalog |
| `manifests/operator-group.yaml` | `OperatorGroup` scoped to the `gitlab-system` namespace |
| `manifests/subscription.yaml` | OLM Subscription for `gitlab-operator-kubernetes` from `operatorhubio-catalog` |
| `manifests/kustomization.yaml` | Kustomize resource list |

## Why a Custom CatalogSource?

GitLab operator 2.9.0+ officially supports OCP 4.21, but the `community-operators-prod` bundle currently annotates its version range as `v4.12-v4.20`, so it does not appear in the OpenShift embedded OperatorHub on 4.21 clusters.

The same operator in the OperatorHub.io catalog (`k8s-operatorhub/community-operators`) carries no OCP version constraint. `catalog-source.yaml` adds `quay.io/operatorhubio/catalog:latest` as a `CatalogSource` named `gitlab-operator-catalog` in `openshift-marketplace`, making the operator visible in the cluster.

The name `gitlab-operator-catalog` is intentionally scoped to avoid colliding with any existing or future `operatorhubio-catalog` source on the cluster.

Once the `community-operators-prod` bundle annotation is updated to include `v4.21`, remove `catalog-source.yaml` and switch `source` in `subscription.yaml` back to `community-operators`.

## Notes

- **Channel:** `stable`
- **Install plan approval:** `Manual` — per GitLab's OpenShift recommendation to prevent unintended operator upgrades; approve the `InstallPlan` after reviewing the upgrade in `oc get installplan -n gitlab-system`
- **OLM install is experimental** — GitLab does not provide support for OLM-deployed instances; see [GitLab operator installation docs](https://docs.gitlab.com/operator/installation/?tab=OpenShift)
- **Dependency:** The GitLab Operator requires cert-manager webhooks to be running. Argo CD will retry automatically.
