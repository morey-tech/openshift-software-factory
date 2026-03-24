---
status: accepted
date: 2026-03-24
---

# Cluster-Wide RBAC for Pipeline SA Cross-Namespace Resolution

## Context and Problem Statement

ADR-0025 established that PipelineRuns in scaffolded app namespaces reference the shared
`build-and-push` Pipeline in `openshift-pipelines` via the Tekton cluster resolver. ADR-0025
noted that the `pipeline` ServiceAccount in each app namespace requires `get` permission on
`Pipeline` resources in `openshift-pipelines`, and deferred the RBAC implementation to Phase 5.4.

How should that RBAC be granted? The golden path template creates a new namespace for each
scaffolded application (e.g. `my-app-dev`). There is no fixed upper bound on the number of app
namespaces, and each one needs the same `pipeline` ServiceAccount permission.

## Decision Drivers

* Every new app namespace produced by the golden path template needs the same permission —
  binding must scale automatically without per-namespace intervention
* The permission required (`get` on `tekton.dev/pipelines`) is read-only on non-sensitive CI
  metadata — not credentials, not workloads
* Operational simplicity: the software factory is meant to reduce toil, not introduce a
  namespace lifecycle management problem

## Considered Options

* **`system:serviceaccounts` ClusterRoleBinding** — one binding grants all SAs in all namespaces
  the permission
* **Per-namespace RoleBindings** — a dedicated RoleBinding is created in each app namespace
  (either manually or via automation) at namespace creation time
* **Name-scoped ClusterRoleBinding targeting `pipeline` ServiceAccount** — ClusterRoleBinding
  that names `serviceaccount: pipeline` — still requires a namespace to be specified, so it
  must be repeated per namespace; there is no way to bind to "all SAs named `pipeline`" without
  `system:serviceaccounts`

## Decision Outcome

Chosen option: **`system:serviceaccounts` ClusterRoleBinding**, because the factory creates
an unbounded number of app namespaces and any per-namespace approach requires either manual
creation or a namespace controller — both contradict the zero-toil goal of the software factory.

### Implementation

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pipeline-cross-namespace-read
rules:
  - apiGroups: [tekton.dev]
    resources: [pipelines]
    verbs: [get]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pipeline-cross-namespace-read
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pipeline-cross-namespace-read
subjects:
  - kind: Group
    apiGroup: rbac.authorization.k8s.io
    name: system:serviceaccounts
```

Deployed via `components/openshift-pipelines/instance/manifests/pipeline-rbac.yaml`.

### Consequences

* Good, because new app namespaces get the required permission automatically — no namespace
  lifecycle hook or manual step needed
* Good, because the permission is read-only (`get`) on `tekton.dev/pipelines` — a non-sensitive
  resource containing only CI pipeline definitions
* Bad, because all ServiceAccounts in all namespaces (including system namespaces) technically
  receive this permission — acceptable given the read-only, non-sensitive nature of the resource

## Pros and Cons of the Options

### `system:serviceaccounts` ClusterRoleBinding

* Good, because zero per-namespace configuration — scales to any number of app namespaces
* Good, because deployed once alongside the Pipeline in `openshift-pipelines`, managed by ArgoCD
* Bad, because technically broader than necessary (all SAs, not just `pipeline` SAs)

### Per-namespace RoleBindings

* Good, because strictly least-privilege — each namespace gets exactly what it needs
* Bad, because requires automation or manual creation per new namespace
* Bad, because introduces a namespace provisioning dependency outside the golden path template

### Name-scoped ClusterRoleBinding targeting `pipeline` SA

* Neutral, because there is no Kubernetes mechanism to bind to "all SAs named `pipeline`
  across all namespaces" — each namespace must be enumerated in `subjects`, making this
  equivalent to per-namespace bindings in practice
* Bad, because does not actually reduce the scope compared to `system:serviceaccounts` in a
  factory where the only service accounts executing PipelineRuns are named `pipeline`
