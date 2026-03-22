# GitLab — Instance

This folder is managed by the `operands` ApplicationSet.

## Contents

| File | Purpose |
|------|---------|
| `config.json` | Declares the target namespace (`gitlab-system`) for the Argo CD Application |
| `manifests/gitlab-root-password-job.yaml` | `ServiceAccount`, `Role`, `RoleBinding`, and `Job` — generates the initial root password Secret |
| `manifests/gitlab-root-password-job.sh` | Shell script (mounted as ConfigMap) that generates the password and creates the Secret with an ownerReference back to the Job |
| `manifests/gitlab.yaml` | `GitLab` CR — deploys GitLab Community Edition (default wave 0, after the password Job at wave -1) |
| `manifests/kustomization.yaml` | Kustomize resource list; generates the script ConfigMap |

## Before Deploying

1. **Set the cluster domain** in `manifests/gitlab.yaml`: replace `CLUSTER_BASE_DOMAIN` with the cluster's apps domain:
   ```bash
   oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'
   ```
2. **Verify the chart version** in `manifests/gitlab.yaml` matches a version supported by the installed operator:
   ```bash
   oc get csv -n gitlab-system -o jsonpath='{.items[0].spec.version}'
   ```

## Initial Root Password

The `job-gitlab-root-password` Job generates a secure random password and creates the `gitlab-initial-root-password` Secret in `gitlab-system`. The Secret carries an `ownerReference` back to the Job so Argo CD displays it as a child resource in the Application UI. See [ADR-0018](../../../docs/decisions/0018-job-generated-secrets-with-owner-references.md).

Retrieve the password after the Job completes:
```bash
oc get secret gitlab-initial-root-password -n gitlab-system -o jsonpath='{.data.password}' | base64 -d
```

## What Is Disabled

| Component | Reason |
|-----------|--------|
| `gitlab-runner` | Tekton (OpenShift Pipelines) handles CI/CD |
| `registry` | Quay serves as the container image registry |
| `gitlab-pages` | Not needed for SCM-only use case |
| `certmanager` (bundled) | OpenShift cert-manager operator is used instead |
| `prometheus` | OpenShift ships Prometheus Adapter; set `prometheus.install=false` |
