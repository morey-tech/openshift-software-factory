---
status: accepted
date: 2026-03-22
---

# Job-Generated Secrets with ownerReferences for Argo CD Visibility

## Context and Problem Statement

Some components require a Secret that must contain a securely generated random value at deploy time — for example, the GitLab initial root password. Storing the plaintext value in the repository violates the principle of not committing secrets. Storing a placeholder requires a manual out-of-band step before the Application will function, and leaves an obvious "REPLACE ME" value in the cluster if the operator forgets.

How can we generate a secure secret at deploy time in a GitOps-compatible, declarative, and idempotent way, while keeping the resulting Secret visible in the Argo CD Application UI?

## Decision Drivers

* Secrets must not be committed to the repository in plaintext
* The generation must be declarative (expressed as manifests in git) and applied by Argo CD
* The generated Secret must be visible in the Argo CD Application resource tree, not appear as an unmanaged orphan
* Idempotent: re-syncing must not overwrite a Secret that already exists (which would break the running service)
* Consistent with the existing Job-based pattern established in [ADR-0016](0016-console-plugin-job-for-enabling-plugins.md)

## Considered Options

* **Job with ownerReference** — a short-lived Job generates the value, creates the Secret, and sets an `ownerReference` on the Secret pointing back to the Job; Argo CD displays the Secret as a child of the Job in the resource tree
* **Sealed Secrets / External Secrets** — encrypt or externalize the secret value; requires additional operator infrastructure not yet in the factory
* **Static placeholder** — commit a placeholder value and document that it must be replaced before syncing; simple but requires manual intervention and leaves a non-functional cluster state if missed

## Decision Outcome

Chosen option: **Job with ownerReference**, because it is fully declarative, generates a cryptographically secure value at deploy time, and makes the resulting Secret visible in the Argo CD UI without requiring additional operators.

### Pattern

The pattern consists of four files co-located with the component's instance manifests:

| File | Purpose |
|------|---------|
| `*-job.yaml` | `ServiceAccount`, `Role`, `RoleBinding`, and `Job` — runs the generation script with least-privilege RBAC |
| `*-job.sh` | Shell script stored as a `ConfigMap` via Kustomize `configMapGenerator`; idempotency check + password generation + Secret creation |
| `kustomization.yaml` | `configMapGenerator` entry to bundle the script; `disableNameSuffixHash: true` so the ConfigMap name is stable |

The Job script:
1. Checks whether the Secret already exists — exits cleanly if so (idempotency)
2. Generates a random value using `openssl rand`
3. Reads its own UID: `oc get job <name> -o jsonpath='{.metadata.uid}'`
4. Creates the Secret with an `ownerReference` pointing to the Job:

```yaml
ownerReferences:
  - apiVersion: batch/v1
    blockOwnerDeletion: false
    controller: true
    kind: Job
    name: <job-name>
    uid: <job-uid>
```

Setting `blockOwnerDeletion: false` means deletion of the Job (e.g., when removing the component) does not block waiting for the Secret to be garbage-collected first. The Secret is garbage-collected after the Job is deleted, which is acceptable because removing the component implies removing its data.

The Job uses `argocd.argoproj.io/sync-wave: "-1"` so it runs before all default-wave (wave 0) resources, ensuring the Secret exists before any CR that depends on it is applied. The consuming CR needs no wave annotation.

### Consequences

* Good, because no secret values are stored in the repository
* Good, because the Secret appears as a child resource in the Argo CD Application UI, making it easy to inspect without treating it as an unmanaged orphan
* Good, because idempotent — re-syncing after the Secret exists is a no-op
* Good, because consistent with the Job-based pattern from ADR-0016
* Bad, because a completed Job remains in the namespace; Argo CD reports it as `Healthy` but it is not garbage-collected automatically
* Bad, because the generated Secret is lost if the Job is deleted (e.g., if the component is uninstalled and reinstalled); the Job will regenerate a new password on the next sync, which may be a breaking change for the running service

### Confirmation

After the Application syncs:
1. The Job appears as `Completed` in Argo CD with the Secret as a child resource
2. `oc get secret <secret-name> -n <namespace>` returns the Secret
3. The dependent component (e.g., GitLab CR) starts successfully using the generated Secret

## Pros and Cons of the Options

### Job with ownerReference

* Good, because fully declarative — no out-of-band steps
* Good, because secure — password generated in-cluster, never stored in git
* Good, because visible in Argo CD UI via ownerReference
* Good, because idempotent — safe to re-sync
* Bad, because completed Job lingers in the namespace
* Bad, because Secret is lost if the Job is deleted (re-install scenario)

### Sealed Secrets / External Secrets

* Good, because industry-standard approach for GitOps secret management
* Good, because Secret value persists independently of in-cluster Jobs
* Bad, because requires additional operator infrastructure (Sealed Secrets controller or External Secrets Operator + a secret backend)
* Bad, because adds operational complexity for a dev/demo factory

### Static placeholder

* Good, because simplest implementation
* Bad, because requires manual out-of-band step before first sync
* Bad, because cluster is non-functional until the placeholder is replaced
* Bad, because the placeholder value may be left in place if the operator forgets
