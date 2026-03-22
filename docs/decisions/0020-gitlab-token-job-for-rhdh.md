---
status: accepted
date: 2026-03-22
---

# Job-Generated GitLab Token for Red Hat Developer Hub

## Context and Problem Statement

Red Hat Developer Hub requires a GitLab personal access token (`GITLAB_TOKEN`) and a
random backend signing secret (`BACKEND_SECRET`) injected via the `rhdh-secrets` Secret.
Previously this Secret was committed to the repository as a placeholder with `REPLACE_WITH_*`
values, requiring a manual out-of-band edit before the RHDH Application could be synced.

How can we generate and provision this token automatically at deploy time, without storing
credentials in git?

## Decision Drivers

* No secrets committed to the repository
* Fully declarative — expressed as manifests applied by Argo CD
* Idempotent — re-syncing must not overwrite an existing token
* Consistent with the Job-generated secret pattern from [ADR-0018](0018-job-generated-secrets-with-owner-references.md)
* GitLab is deployed independently (separate Argo CD Application); the solution must
  tolerate GitLab not being ready when the RHDH Application first syncs

## Considered Options

* **Job with ownerReference** — a short-lived Job calls the GitLab API to create a
  personal access token, stores it in `rhdh-secrets`, and sets an `ownerReference` back to itself
* **External Secrets Operator** — synchronise the token from an external secret store
* **Static placeholder** — commit placeholder values and document manual replacement

## Decision Outcome

Chosen option: **Job with ownerReference**, because it extends the established ADR-0018
pattern to a cross-component credential provisioning scenario without requiring additional
operator infrastructure.

### Pattern

Four files are added to `components/developer-hub/instance/manifests/`:

| File | Purpose |
|------|---------|
| `rhdh-gitlab-token-job.yaml` | `ServiceAccount`, `Role`/`RoleBinding` in `rhdh`, `Role`/`RoleBinding` in `gitlab-system`, and `Job` |
| `rhdh-gitlab-token-job.sh` | Shell script (mounted via ConfigMap); idempotency check, API calls, Secret creation |
| `kustomization.yaml` | `configMapGenerator` entry to bundle the script with `disableNameSuffixHash: true` |

The Job script:
1. Exits cleanly if `rhdh-secrets` already exists (idempotency)
2. Reads `appsDomain` from the `cluster-config` ConfigMap in `gitlab-system`
3. Reads the root password from `gitlab-initial-root-password` in `gitlab-system`
4. Polls `https://gitlab.<appsDomain>/-/health` until GitLab is ready (up to 10 minutes)
5. Exchanges root credentials for an OAuth token (`POST /oauth/token`)
6. Creates a root personal access token with scopes `read_api`, `read_repository`,
   `write_repository` (`POST /api/v4/users/1/personal_access_tokens`)
7. Generates `BACKEND_SECRET` with `openssl rand -base64 32`
8. Creates `rhdh-secrets` in `rhdh` with an `ownerReference` pointing to the Job

### Cross-Namespace RBAC

The Job runs in the `rhdh` namespace but must read secrets from `gitlab-system`.
Two pairs of `Role` + `RoleBinding` are declared in `rhdh-gitlab-token-job.yaml`:

| Namespace | Access granted |
|-----------|----------------|
| `rhdh` | `get`/`create` on `secrets`; `get` on `jobs` |
| `gitlab-system` | `get` on `gitlab-initial-root-password` secret and `cluster-config` configmap |

Both resources are owned by the `developer-hub` Argo CD Application.
The Argo CD application controller service account has cluster-scoped permissions and
can create resources in any namespace.

### Sync Waves

| Wave | Resources |
|------|-----------|
| `-2` | `ServiceAccount`, `Role`, `RoleBinding`, script `ConfigMap` |
| `-1` | `Job` (runs before the `Backstage` CR at wave 0) |
| `0` | `Backstage` CR and other RHDH resources |

### Consequences

* Good, because no credentials are stored in git
* Good, because the Secret is visible in the Argo CD UI as a child of the Job (via ownerReference)
* Good, because idempotent — re-syncing after the Secret exists is a no-op
* Good, because the health-check retry loop handles the cross-application timing dependency
  (GitLab deployed separately)
* Bad, because the completed Job remains in the namespace (consistent with ADR-0018)
* Bad, because the token is a root personal access token; a dedicated service account with
  a group access token would be preferable once the `software-factory` GitLab group exists

## Pros and Cons of the Options

### Job with ownerReference

* Good, because fully declarative and consistent with ADR-0018
* Good, because no additional operators required
* Good, because handles cross-application timing via health-check polling
* Bad, because uses root credentials (acceptable for initial bootstrap)

### External Secrets Operator

* Good, because industry-standard GitOps secret management
* Bad, because requires an external secret backend (Vault, AWS Secrets Manager, etc.)
* Bad, because adds operational complexity not justified for a dev/demo factory

### Static placeholder

* Good, because simplest to implement
* Bad, because requires manual out-of-band step before every fresh deployment
* Bad, because leaves a non-functional cluster state if the operator forgets to replace values
