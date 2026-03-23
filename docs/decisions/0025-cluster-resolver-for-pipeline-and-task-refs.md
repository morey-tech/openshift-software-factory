---
status: accepted
date: 2026-03-23
---

# Cluster Resolver for Cross-Namespace Pipeline and Task References

## Context and Problem Statement

The `build-and-push` Tekton Pipeline is deployed to the `openshift-pipelines` namespace so it
can be shared across all application namespaces that contain scaffolded app PipelineRuns.
The Pipeline itself must reference the bundled Tasks (`git-clone`, `buildah`) that the
Pipelines operator installs in `openshift-pipelines`.

Tekton Pipelines are namespace-scoped — there is no `ClusterPipeline` resource type.
Tekton Tasks are also namespace-scoped; `ClusterTask` was the historical cross-namespace
mechanism but was deprecated in OpenShift Pipelines 1.14 and **removed in 1.21**.

How should cross-namespace Pipeline and Task references be expressed in a way that is
compatible with OpenShift Pipelines 1.21+?

## Decision Drivers

* OpenShift Pipelines 1.21 has removed `ClusterTask` — any `taskRef.name: git-clone`
  without a resolver will fail at runtime
* The `build-and-push` Pipeline must be referenceable from PipelineRuns in any application
  namespace without copying the Pipeline manifest per namespace
* The solution must be compatible with the stable Tekton `v1` API

## Considered Options

* **ClusterTask references** — `taskRef.name: git-clone` (deprecated and removed in 1.21)
* **Copy Pipeline per namespace** — duplicate `pipeline-build-push.yaml` into each app namespace
* **Cluster resolver** — `taskRef.resolver: cluster` / `pipelineRef.resolver: cluster`

## Decision Outcome

Chosen option: **Cluster resolver**, because it is the officially supported cross-namespace
reference mechanism in OpenShift Pipelines 1.17+ and the only supported option in 1.21.

### How it works

**Task references within the Pipeline** use the cluster resolver to reference Tasks
in the `openshift-pipelines` namespace where the operator installs bundled Tasks:

```yaml
taskRef:
  resolver: cluster
  params:
    - {name: kind,      value: task}
    - {name: name,      value: git-clone}
    - {name: namespace, value: openshift-pipelines}
```

**PipelineRun references** from application namespaces use the cluster resolver to
reference the `build-and-push` Pipeline in `openshift-pipelines`:

```yaml
pipelineRef:
  resolver: cluster
  params:
    - {name: kind,      value: pipeline}
    - {name: name,      value: build-and-push}
    - {name: namespace, value: openshift-pipelines}
```

**The write-back task** (`update-gitops`) uses an inline `taskSpec` within the Pipeline
rather than a separate Task resource. No operator-managed equivalent exists for the
kustomize-edit + git-commit write-back pattern, and inlining keeps the complete pipeline
definition in one file.

### RBAC consideration

The `pipeline` ServiceAccount in each application namespace needs `get` permission on
`Pipeline` resources in `openshift-pipelines` for the cluster resolver to succeed.
A `ClusterRole` + `ClusterRoleBinding` granting this access to all `pipeline`
ServiceAccounts across all namespaces must be created alongside the PipelineRun skeleton
in Phase 5.4. This is documented in the Phase 5.4 plan.

### Consequences

* Good, because ClusterTask deprecation is fully avoided — forward-compatible with future
  Pipelines operator upgrades
* Good, because a single Pipeline in `openshift-pipelines` is shared across all app
  namespaces — no duplication per namespace
* Good, because operator-managed Tasks (`git-clone`, `buildah`) receive security patches
  automatically when the operator upgrades them
* Bad, because the `pipeline` ServiceAccount in each app namespace requires a
  ClusterRoleBinding for cross-namespace read access (addressed in Phase 5.4)
* Bad, because the cluster resolver requires the `cluster-resolver` feature flag;
  this is enabled by default in OpenShift Pipelines 1.17+ but should be verified if
  `TektonConfig` is customised

## Pros and Cons of the Options

### ClusterTask references

* Good, because historically simple — `taskRef.name: git-clone` with no resolver
* Bad, because deprecated since 1.14
* Bad, because removed in 1.21 — will fail at runtime on current versions

### Copy Pipeline per namespace

* Good, because no cross-namespace RBAC dependency
* Bad, because N copies must be maintained for N apps — drift is inevitable
* Bad, because Pipeline updates must be applied to every app namespace individually

### Cluster resolver

* Good, because officially supported and recommended for OpenShift Pipelines 1.17+
* Good, because single source of truth in `openshift-pipelines`
* Good, because consistent reference model for both Tasks and Pipelines
* Bad, because cross-namespace RBAC must be granted for the `pipeline` ServiceAccount
