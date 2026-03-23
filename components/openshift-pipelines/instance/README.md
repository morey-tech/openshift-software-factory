# OpenShift Pipelines — Instance

The OpenShift Pipelines operator automatically creates and manages the instance on install. This directory also contains shared Tekton resources used by the golden path template.

## Auto-provisioned resources

| Resource | Name | Description |
|----------|------|-------------|
| `TektonConfig` | `config` | Top-level CR that drives the full Pipelines install |
| `TektonPipeline` | `pipeline` | Provisions the Pipelines controllers and CRDs |
| `TektonTrigger` | `trigger` | Provisions the Triggers controllers and CRDs |

These are reconciled by the operator and do not need to be declared in this repository. To verify:

```bash
oc get tektonconfig,tektonpipeline,tektontrigger -A
```

## Shared Pipelines (Phase 5)

| Resource | Name | Namespace | Purpose |
|----------|------|-----------|---------|
| `Pipeline` | `build-and-push` | `openshift-pipelines` | Clone source → buildah push to Quay → update GitOps repo image tag |

Scaffolded app PipelineRuns reference this Pipeline cross-namespace using the cluster resolver:

```yaml
pipelineRef:
  resolver: cluster
  params:
    - {name: kind,      value: pipeline}
    - {name: name,      value: build-and-push}
    - {name: namespace, value: openshift-pipelines}
```

See [ADR-0025](../../../docs/decisions/0025-cluster-resolver-for-pipeline-and-task-refs.md) for the decision to use the cluster resolver over ClusterTasks (removed in OpenShift Pipelines 1.21).
