# Developer Hub — Instance

This folder is managed by the `operands` ApplicationSet.

## Contents

| File | Purpose |
|------|---------|
| `config.json` | Declares the target namespace (`rhdh`) for the Argo CD Application |
| `manifests/backstage.yaml` | `Backstage` CR — deploys the RHDH 1.9 instance |
| `manifests/app-config-rhdh.yaml` | ConfigMap with the Backstage app-config (GitLab integration, guest auth, catalog discovery) |
| `manifests/dynamic-plugins-rhdh.yaml` | ConfigMap listing enabled dynamic plugins |
| `manifests/rhdh-gitlab-token.yaml` | Secret with `GITLAB_TOKEN` and `BACKEND_SECRET` placeholders |
| `manifests/dynamic-plugins-root-pvc.yaml` | PVC for caching dynamic plugin downloads across pod restarts |
| `manifests/kustomization.yaml` | Kustomize resource list |

## Before Deploying

1. **Set the GitLab token** in `manifests/rhdh-gitlab-token.yaml`: replace `REPLACE_WITH_GITLAB_TOKEN` with a GitLab group access token (`read_api` + `read_repository` scopes). See the [GitLab README](../../../gitlab/README.md) for setup steps.
2. **Set the backend secret** in `manifests/rhdh-gitlab-token.yaml`: replace `REPLACE_WITH_RANDOM_SECRET` with a random value (`openssl rand -base64 32`).
3. **Set the GitLab route host** in `manifests/app-config-rhdh.yaml`: replace `<GITLAB_ROUTE_HOST>` with the actual GitLab hostname:
   ```bash
   oc get route -n gitlab-system -o jsonpath='{.items[0].spec.host}'
   ```

## Namespace

The instance runs in `rhdh`, separate from the `rhdh-operator` namespace. See [ADR-0015](../../../docs/decisions/0015-developer-hub-instance-namespace.md).

## Authentication

Configured for guest sign-in (`signInPage: guest`) for initial setup. Replace with GitLab OAuth or an OIDC provider in Phase 4.

## Dynamic Plugins

| Plugin | Purpose |
|--------|---------|
| `catalog-backend-module-gitlab-dynamic` | Discovers `catalog-info.yaml` files from the `software-factory` GitLab group |
| `backstage-plugin-argo-cd` | Shows Argo CD sync status on component pages |
| `backstage-plugin-kubernetes` | Connects to the local OpenShift cluster |
| `janus-idp-backstage-plugin-topology` | Kubernetes topology view on component pages |
| `janus-idp-backstage-plugin-tekton` | Shows Tekton PipelineRun status on component pages |
