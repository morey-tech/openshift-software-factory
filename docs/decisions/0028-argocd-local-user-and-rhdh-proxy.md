---
status: accepted
date: 2026-03-24
---

# ArgoCD Local User and Backstage Proxy for RHDH Integration

## Context and Problem Statement

Red Hat Developer Hub (RHDH) requires an ArgoCD API token to power two features:

1. **ArgoCD backend plugin** — displays the sync status and health of ArgoCD Applications
   on RHDH component pages.
2. **Scaffolder `createArgoApp` action** — creates an ArgoCD Application as part of the
   golden path template when a developer scaffolds a new service.

The token must be injected into RHDH at startup (via `rhdh-secrets`) and routed to the
ArgoCD API via a Backstage proxy endpoint so that browser-side plugin calls do not expose
the token directly to end users.

How should the ArgoCD token be obtained, stored, and delivered to the plugins?

## Decision Drivers

* Least privilege — RHDH must not hold cluster-admin or ArgoCD admin credentials
* No long-lived admin secrets stored in `rhdh-secrets`
* Token lifecycle managed declaratively by the ArgoCD operator, not by ad-hoc scripts
* Consistent with the job-generated secrets pattern from [ADR-0018](0018-job-generated-secrets-with-owner-references.md) and [ADR-0020](0020-gitlab-token-job-for-rhdh.md)
* Token must be available before the Backstage CR starts (sync-wave ordering)

## Considered Options

* **ArgoCD local user with `autoRenewToken`** — declare a `rhdh` local user in the ArgoCD
  CR; the operator stores and rotates the token in a Secret; the init job reads the Secret
* **Admin token via API** — the init job authenticates with the ArgoCD admin password and
  calls `POST /api/v1/session` to mint a token, stored in `rhdh-secrets`
* **OpenShift service account / OIDC** — use a Kubernetes service account token federated
  through ArgoCD's OIDC provider

## Decision Outcome

Chosen option: **ArgoCD local user with `autoRenewToken`**, because it provides a
dedicated least-privilege identity whose token lifecycle is managed entirely by the
ArgoCD operator — no admin credentials need to leave the `openshift-gitops` namespace.

### ArgoCD CR Changes (`argocd.yaml`)

A `localUsers` entry is added to the `ArgoCD` CR:

```yaml
localUsers:
  - name: rhdh
    apiKey: true
    tokenLifetime: "0"   # non-expiring
```

The ArgoCD operator creates a Secret named **`rhdh-local-user`** in the `openshift-gitops`
namespace containing the current API token (base64-encoded under the `token` key). The
operator rotates this Secret automatically before the token expires.

RBAC policy entries are added so the `rhdh` user has only the permissions the plugins need:

```
p, rhdh, applications, get,    */*, allow
p, rhdh, applications, create, */*, allow
p, rhdh, applications, sync,   */*, allow
p, rhdh, projects,     get,    */*, allow
```

### Init Job Changes (`rhdh-secrets-init-job`)

The job (renamed from `rhdh-gitlab-token-job` as its scope expanded) is granted `get` on
the `rhdh-local-user` Secret in `openshift-gitops` via a dedicated `Role` +
`RoleBinding`. After writing the GitLab token it reads `rhdh-local-user` and stores
`ARGOCD_TOKEN` in `rhdh-secrets` alongside the existing fields.

`ARGOCD_TOKEN` is treated as a **stable/patchable** field: if it is missing from an
existing `rhdh-secrets` (e.g. after an upgrade that added this field) the job patches it
in without touching `GITLAB_TOKEN` or `BACKEND_SECRET`.

### Backstage Proxy (`app-config-rhdh.yaml`)

The ArgoCD plugin communicates with the ArgoCD API through a server-side Backstage proxy
so that the token is never sent to the browser:

```yaml
proxy:
  endpoints:
    '/argocd/api':
      target: 'https://software-factory-argocd-server.openshift-gitops.svc'
      changeOrigin: true
      secure: false
      pathRewrite:
        '^/api/proxy/argocd/api': '/api/v1'
      headers:
        Cookie: 'argocd.token=${ARGOCD_TOKEN}'
```

`ARGOCD_TOKEN` is injected from `rhdh-secrets` via `extraEnvVarsSecrets` on the
`Backstage` CR, following the same pattern used for `GITLAB_TOKEN` and `BACKEND_SECRET`.

### Consequences

* Good, because the `rhdh` user has least-privilege access (no admin role)
* Good, because the token is non-expiring (`tokenLifetime: "0"`) — no rotation needed for a dedicated internal service account
* Good, because no admin credentials are ever written to `rhdh-secrets`
* Good, because the proxy pattern keeps the token server-side
* Neutral, because the `rhdh-local-user` Secret must exist before the init job runs;
  if the ArgoCD operator has not yet generated it the job will fail and retry (backoffLimit: 4)

## Pros and Cons of the Options

### ArgoCD local user with `autoRenewToken`

* Good, because token lifecycle is declarative and operator-managed
* Good, because dedicated identity with minimal RBAC
* Good, because no admin credentials needed outside `openshift-gitops`
* Neutral, because the Secret name (`{username}-local-user`) is operator-defined and
  must be verified against the installed OpenShift GitOps version

### Admin token via API

* Good, because no ArgoCD CR changes needed
* Bad, because stores an admin-equivalent token in `rhdh-secrets`
* Bad, because requires the init job to hold admin credentials transiently

### OpenShift service account / OIDC

* Good, because leverages existing cluster identity infrastructure
* Bad, because ArgoCD's OIDC integration adds significant configuration complexity
* Bad, because service account tokens have short default lifetimes requiring refresh logic
