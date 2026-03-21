# OpenShift Pipelines — Operator

This folder is managed by the `operators` ApplicationSet.

## Contents

| File | Purpose |
|------|---------|
| `config.json` | Declares the target namespace (`openshift-operators`) for the Argo CD Application |
| `manifests/subscription.yaml` | OLM Subscription for the `openshift-pipelines-operator-rh` operator from `redhat-operators` |
| `manifests/kustomization.yaml` | Kustomize component enabling the Pipelines console plugin |
| `manifests/console-plugin.yaml` | `ConsolePlugin` CR to register the Pipelines UI in the OpenShift console |
| `manifests/console-plugin-job.yaml` | `Job`, `ServiceAccount`, and RBAC to patch the cluster console and activate the plugin |
| `manifests/console-plugin-job.sh` | Shell script executed by the job to enable the plugin via `oc patch` |

## Notes

- **Channel:** `pipelines-1.21`
- **Install plan approval:** Automatic
- **Namespace:** Installs into `openshift-operators` (global operator namespace) — no OperatorGroup needed
- **Console plugin:** Sourced from [redhat-cop/gitops-catalog](https://github.com/redhat-cop/gitops-catalog/tree/main/openshift-pipelines-operator/components/enable-console-plugin)
- **Auto-provisioned instance:** The operator automatically creates a `TektonConfig/config` CR on install, which in turn provisions `TektonPipeline/pipeline` and `TektonTrigger/trigger`. No instance manifests are needed — an `instance/` component for OpenShift Pipelines is not required.
