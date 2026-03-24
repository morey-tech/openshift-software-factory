---
status: accepted
date: 2026-03-23
---

# Job-Based GitLab Group Bootstrap for RHDH Catalog Discovery

## Context and Problem Statement

The RHDH `gitlabOrg` catalog provider is configured to discover components from the
`software-factory` GitLab group. The golden path template (Phase 5) publishes scaffolded
application repos into `software-factory/apps`, and the catalog entry point lives in
`software-factory/platform/software-factory-catalog`. None of these groups or repositories
exist after a fresh GitLab deployment — the GitLab Operator only provisions the GitLab
instance itself, not any group or project structure within it.

How can the required GitLab group hierarchy and catalog seed repo be created automatically
at deploy time, without manual intervention and without storing credentials in git?

## Decision Drivers

* No manual steps after `ansible-playbook bootstrap.yaml` — the factory must self-configure
* No credentials committed to the repository
* Fully declarative — expressed as manifests applied by Argo CD
* Idempotent — re-syncing must not fail or duplicate groups if they already exist
* Consistent with the existing Job-based bootstrap pattern established in
  [ADR-0018](0018-job-generated-secrets-with-owner-references.md) and
  [ADR-0020](0020-gitlab-token-job-for-rhdh.md)
* Must tolerate GitLab's long cold-start time (initial deployment can take 30–60 minutes
  for Postgres migrations and asset compilation)

## Considered Options

* **Job calling the GitLab API** — a short-lived Kubernetes Job runs a shell script that
  polls until GitLab is healthy, then creates the groups and seed repo via the GitLab REST API
* **GitLab Operator CR extensions** — configure groups via the GitLab CR or an additional
  GitLab-operator-managed resource
* **Terraform/Ansible post-step** — create groups via a separate Terraform provider or
  Ansible module run after bootstrap

## Decision Outcome

Chosen option: **Job calling the GitLab API**, because it follows the established Job
bootstrap pattern used by `gitlab-root-password-job` and `gitlab-domain-init-job`, requires
no additional tooling, and keeps the entire bootstrap flow within the Argo CD sync lifecycle.

### Pattern

Three files are added to `components/gitlab/instance/manifests/`:

| File | Purpose |
|------|---------|
| `gitlab-platform-init-job.yaml` | `ServiceAccount`, `Role`/`RoleBinding`, `ClusterRole`/`ClusterRoleBinding`, and `Job` |
| `gitlab-platform-init-job.sh` | Shell script (mounted via ConfigMap); idempotency check, group creation, catalog seeding |
| `kustomization.yaml` | `configMapGenerator` entry to bundle the script |

The Job script:
1. Exits cleanly if the `software-factory` group already exists (idempotency)
2. Discovers `APPS_DOMAIN` from `ingresses.config.openshift.io/cluster`
3. Reads the root password from `gitlab-initial-root-password` in `gitlab-system`
4. Polls `https://gitlab.<APPS_DOMAIN>/-/health` until GitLab is ready (up to 60 minutes,
   360 attempts × 10s — longer than other jobs to cover GitLab's initial cold-start)
5. Exchanges root credentials for an OAuth token (`POST /oauth/token`)
6. Creates the top-level group `software-factory` (`POST /api/v4/groups`)
7. Creates subgroup `software-factory/platform` (for platform-owned repos)
8. Creates subgroup `software-factory/apps` (for repos scaffolded by the golden path template)
9. Creates project `software-factory/platform/software-factory-catalog` with `initialize_with_readme: true`
10. Seeds `catalog-info.yaml` into that project via the GitLab files API (`POST /api/v4/projects/:id/repository/files/`) — a Backstage `Location` pointing to the golden path template in this repo

### GitLab Group Structure

```
software-factory/          ← RHDH gitlabOrg provider targets this group
├── platform/              ← platform-owned repos; RHDH discovers catalog-info.yaml files here
│   └── software-factory-catalog
│       └── catalog-info.yaml   ← Location pointing to the golden path template
└── apps/                  ← repos created by the RHDH golden path template
    ├── <app-name>         ← source repo (scaffolded)
    └── <app-name>-gitops  ← GitOps repo with ArgoCD Application (scaffolded)
```

### RBAC

The Job runs in `gitlab-system` and only needs:

| Scope | Access |
|-------|--------|
| `Role` in `gitlab-system` | `get` on `gitlab-initial-root-password` secret |
| `ClusterRole` | `get` on `ingresses.config.openshift.io` |

No `get jobs` permission is needed because this Job does not create Secrets with
`ownerReferences` (it creates GitLab resources via API, not Kubernetes resources).

### Sync Waves

| Wave | Resources |
|------|-----------|
| `-2` | `ServiceAccount`, `Role`, `RoleBinding`, `ClusterRole`, `ClusterRoleBinding`, script `ConfigMap` |
| `0` | GitLab CR (applied by Argo CD) |
| `1` | `Job` — runs after the GitLab CR exists; polls until GitLab is actually healthy |

### Consequences

* Good, because fully declarative and consistent with the existing Job bootstrap pattern
* Good, because no credentials are stored in git
* Good, because idempotent — re-syncing after groups exist exits cleanly
* Good, because the 60-minute health-check loop handles GitLab's slow initial cold-start
* Good, because the catalog seed means RHDH discovers the golden path template automatically
  via `gitlabOrg` without needing a static `catalog.locations` entry
* Bad, because the completed Job remains in the namespace (consistent with ADR-0018)
* Bad, because uses the GitLab root OAuth token; a group access token would be preferable
  for production use, but is bootstrapped here before the group exists

### Confirmation

Deployment is confirmed when:
- `oc get job job-gitlab-platform-init -n gitlab-system -o jsonpath='{.status.succeeded}'` returns `1`
- The groups `software-factory`, `software-factory/platform`, and `software-factory/apps`
  are visible in the GitLab UI
- `software-factory/platform/software-factory-catalog` exists and contains `catalog-info.yaml`
- RHDH catalog shows the golden path template under the Templates section

## Pros and Cons of the Options

### Job calling the GitLab API

* Good, because follows the established Job bootstrap pattern — no new concepts introduced
* Good, because the health-check polling loop decouples the job from GitLab's variable startup time
* Good, because all resources are owned by the same Argo CD Application as the GitLab instance
* Bad, because uses root credentials (acceptable for initial bootstrap)
* Bad, because JSON construction without `jq` requires careful string handling

### GitLab Operator CR extensions

* Good, because declarative at the CR level
* Bad, because the GitLab Operator does not expose any CRD for groups or projects
* Bad, because would require forking or patching the operator

### Terraform/Ansible post-step

* Good, because the GitLab Terraform provider has first-class group/project support
* Bad, because introduces a second tool and a second execution step outside the Argo CD lifecycle
* Bad, because breaks the single-playbook bootstrap model
