# OpenShift Pipelines — Instance

No manifests are required here. The OpenShift Pipelines operator automatically creates and manages the instance on install.

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
