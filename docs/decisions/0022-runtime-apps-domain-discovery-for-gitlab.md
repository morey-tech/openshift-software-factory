---
status: accepted
date: 2026-03-23
supersedes: 0019-kustomize-replacements-for-cluster-specific-values.md
---

# Runtime Apps Domain Discovery for GitLab

## Context and Problem Statement

ADR-0019 introduced a `cluster-config.yaml` ConfigMap that stores the cluster's apps subdomain and injects it into the GitLab CR at Kustomize build time via `replacements`. This works, but requires a human to edit `cluster-config.yaml` before every deployment to a new cluster — easy to forget and couples the repository to a single cluster.

The apps domain is always discoverable at runtime: `kubectl get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'`. The goal is to remove the manual pre-deploy step entirely.

## Decision Drivers

* Bootstrap must complete with **no edits to any file in the repository**
* The solution must stay within the existing OLM + Argo CD + Job toolchain
* Must be idempotent (safe to re-sync)
* Must not regress the developer-hub token job that also reads `appsDomain`

## Considered Options

* **Ansible creates the ConfigMap** — Ansible queries the ingress config and applies a `cluster-config` ConfigMap to the cluster before Argo CD syncs. Rejected: Kustomize replacements run at *render time* from git, so Argo CD would overwrite the Ansible-created ConfigMap with the git placeholder on every sync.
* **Job + Server-Side Apply** — A sync-wave Job discovers the domain at sync time and patches the GitLab CR. SSA ensures Argo CD never takes field ownership of the domain, so `selfHeal` cannot revert it.

## Decision Outcome

Chosen option: **Job + Server-Side Apply**.

### How it works

1. `spec.chart.values.global.hosts.domain` is **removed** from `gitlab.yaml`. The GitLab CR carries the annotation `argocd.argoproj.io/sync-options: ServerSideApply=true`.

2. A new `job-gitlab-domain-init` Job runs at **sync wave 1** (after the GitLab CR at wave 0):
   - Queries `ingresses.config.openshift.io/cluster` for `.spec.domain`
   - Patches the GitLab CR's `spec.chart.values.global.hosts.domain` via `kubectl patch --type=merge`
   - Idempotent: exits cleanly if the field is already set

3. Because the domain field is **absent from git**, Argo CD's SSA field manager never owns it. Subsequent syncs leave the field untouched.

4. The same pattern replaces the `cluster-config` ConfigMap read in the developer-hub token job: `rhdh-gitlab-token-job.sh` now queries the ingress config directly.

### Sync wave table (gitlab-instance Application)

| Wave | Resources |
|------|-----------|
| `-2` | ServiceAccount, ClusterRole, ClusterRoleBinding, Role, RoleBinding, script ConfigMap |
| `0`  | GitLab CR (SSA; domain field absent) |
| `1`  | `job-gitlab-domain-init` — patches domain |

### Consequences

* Good, because bootstrap requires no manual file edits — zero pre-deploy configuration.
* Good, because `cluster-config.yaml` is removed from the repository entirely; there is no stale placeholder to forget to update.
* Good, because idempotent — re-syncing the Application is safe.
* Good, because consistent with the Job-generated secret pattern from ADR-0018 and ADR-0020.
* Bad, because there is a brief window between wave 0 (GitLab CR applied without domain) and wave 1 (domain patched) during which the GitLab operator begins reconciling with an empty domain. The operator reconciles continuously and recovers once the domain is set; this is acceptable for a bootstrap scenario.
* Bad, because the completed Job remains in `gitlab-system` (consistent with ADR-0018).

### Confirmation

After a clean bootstrap with no file edits:

```bash
# Domain is set on the CR
kubectl get gitlab gitlab -n gitlab-system \
  -o jsonpath='{.spec.chart.values.global.hosts.domain}'
# Expected: apps.<cluster-id>.<base-domain>

# SSA field ownership — domain is NOT in argocd's managed fields
kubectl get gitlab gitlab -n gitlab-system -o json \
  | jq '.metadata.managedFields[] | select(.manager=="argocd") | .fieldsV1'
# Expected: no entry for f:spec > f:chart > f:values > f:global > f:hosts > f:domain

# Re-sync does not revert the domain
argocd app sync gitlab-instance
kubectl get gitlab gitlab -n gitlab-system \
  -o jsonpath='{.spec.chart.values.global.hosts.domain}'
# Expected: same domain as before
```

## Supersedes

[ADR-0019 — Kustomize Replacements for Cluster-Specific Values](0019-kustomize-replacements-for-cluster-specific-values.md)

`cluster-config.yaml` has been removed. The `replacements` block has been removed from `components/gitlab/instance/manifests/kustomization.yaml`.
