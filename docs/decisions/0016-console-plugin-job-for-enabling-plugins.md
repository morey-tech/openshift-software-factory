---
status: accepted
date: 2026-03-22
---

# Console Plugin Job for Enabling Operator Plugins

## Context and Problem Statement

Several OpenShift operators ship a console plugin that must be explicitly activated in the cluster console before its UI features become visible. Activation requires patching `consoles.operator.openshift.io/cluster` to add the plugin name to `spec.plugins`. This patch is a cluster-scoped, imperative operation — it cannot be expressed as a declarative manifest applied by Argo CD in the normal way, because the target object is a singleton cluster resource managed by the OpenShift console operator, not owned by any application.

How should the software factory enable operator-provided console plugins in a GitOps-compatible, repeatable way?

## Decision Drivers

* GitOps compatibility: all configuration should be expressed as manifests in the repository and applied by Argo CD
* Idempotency: re-syncing the Argo CD Application must not fail or re-patch an already-enabled plugin
* Minimal footprint: no persistent workloads; the activation is a one-time operation per cluster
* Reusability: the same pattern should work for any operator that ships a console plugin (Pipelines, GitOps, etc.)

## Considered Options

* **Kubernetes Job with `oc patch`** — a short-lived Job runs `oc patch consoles.operator.openshift.io cluster` to append the plugin name; a shell script handles idempotency
* **Argo CD Resource Hook** — a `PreSync` or `PostSync` hook Job triggers the patch during each sync
* **Manual activation** — document the `oc patch` command and rely on the operator to run it after install

## Decision Outcome

Chosen option: **Kubernetes Job with `oc patch`**, because it is declarative (the Job manifest lives in the repository), idempotent (the script checks whether the plugin is already present before patching), and self-contained (no external tooling or manual steps required).

The pattern consists of four files co-located with the operator's manifests:

| File | Purpose |
|------|---------|
| `console-plugin.yaml` | `ConsolePlugin` CR — registers the plugin's backend service with the console |
| `console-plugin-job.yaml` | `ServiceAccount`, `ClusterRole`, `ClusterRoleBinding`, and `Job` — runs the activation script with least-privilege RBAC |
| `console-plugin-job.sh` | Shell script stored as a `ConfigMap`; checks for existing plugin entry before patching |
| `kustomization.yaml` | Kustomize `Component` — bundles all resources and generates the `ConfigMap` from the script file |

The Job uses `argocd.argoproj.io/sync-wave: "10"` to ensure it runs after the `ConsolePlugin` CR and the operator subscription are applied.

### Consequences

* Good, because the entire activation flow is expressed as manifests in git — no out-of-band steps required
* Good, because the idempotency check (`if [[ "${INSTALLED_PLUGINS}" == *"${PLUGIN_NAME}"* ]]`) prevents duplicate entries on re-sync
* Good, because the same script and Job structure can be reused verbatim across operators — only names and `PLUGIN_NAME` differ
* Good, because the Job is short-lived and leaves no persistent workload running after activation
* Bad, because a completed Job remains in the namespace; Argo CD will report it as `Healthy` but it is not garbage-collected automatically
* Bad, because if the cluster console object is not yet available when the Job runs, the Job will exhaust its `backoffLimit` and require a manual re-sync

### Confirmation

After syncing the Argo CD Application, confirm the plugin is active:
```bash
oc get consoles.operator.openshift.io cluster -o jsonpath='{.spec.plugins}'
```
The plugin name should appear in the output. Verify the UI extension loads in the OpenShift web console.

## Pros and Cons of the Options

### Kubernetes Job with `oc patch`

* Good, because fully declarative and GitOps-compatible
* Good, because idempotent — safe to re-sync repeatedly
* Good, because reusable pattern across all operator console plugins
* Bad, because completed Jobs accumulate in the namespace unless pruned

### Argo CD Resource Hook

* Good, because runs automatically on every sync, ensuring the plugin stays enabled even if manually removed
* Bad, because hooks run on every sync — unnecessary overhead once the plugin is already enabled
* Bad, because hook Jobs are harder to inspect and debug than regular Jobs

### Manual activation

* Good, because simplest implementation — no manifests needed
* Bad, because violates the GitOps principle that all cluster state should be expressed in the repository
* Bad, because undocumented in the cluster state — a new deployment has no record of what needs to be done
