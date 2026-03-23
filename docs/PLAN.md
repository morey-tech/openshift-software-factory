# Enterprise Software Factory — Project Plan

This document outlines the work required to build out this repository with all the OpenShift manifests and automation needed to bootstrap an empty cluster into a fully functional software factory.

## Architecture Overview

```
Ansible Playbook
  └── Installs OpenShift GitOps Operator
        └── Creates Root Argo CD Application
              └── Deploys 2 ApplicationSets
                    ├── Operators AppSet  → reads config.json from components/*/operator/
                    └── Operands AppSet   → reads config.json from components/*/instance/
```

Adding a new component = add a folder under `components/` with `operator/` and/or `instance/` subdirectories, each containing a `config.json` that declares the component's name, namespace, and any other metadata. The ApplicationSets use the **git files generator** to discover these config files and template Applications accordingly.

> **Why config.json?** OpenShift operators are often picky about namespaces (e.g. OpenShift Virtualization's operator `kubevirt-hyperconverged` must deploy into `openshift-cnv`). Folder names should be human-friendly, not constrained by namespace requirements. See [ADR-0001](decisions/0001-use-git-files-generator-for-applicationsets.md) for the full rationale.

## Proposed Directory Structure

```
├── PLAN.md
├── README.md
├── ansible/
│   ├── playbook.yml                # Bootstrap playbook
│   ├── inventory/
│   └── roles/
│       └── bootstrap-gitops/       # Install GitOps operator + create root App
├── bootstrap/
│   ├── root-application.yaml       # Root Argo CD Application (deploys the AppSets)
│   ├── operators-appset.yaml       # ApplicationSet: git files generator → components/*/operator/config.json
│   └── operands-appset.yaml        # ApplicationSet: git files generator → components/*/instance/config.json
├── components/
│   ├── openshift-gitops/
│   │   ├── operator/
│   │   │   ├── config.json         # { "name": "openshift-gitops", "namespace": "openshift-gitops-operator" }
│   │   │   └── *.yaml              # Subscription, OperatorGroup
│   │   └── instance/
│   │       ├── config.json
│   │       └── *.yaml              # ArgoCD CR, RBAC, AppProjects
│   ├── openshift-pipelines/
│   │   ├── operator/
│   │   │   ├── config.json
│   │   │   └── *.yaml              # Subscription, OperatorGroup
│   │   └── instance/
│   │       ├── config.json
│   │       └── *.yaml              # TektonConfig, shared Tasks/Pipelines
│   ├── quay/
│   │   ├── operator/
│   │   │   ├── config.json
│   │   │   └── *.yaml              # Subscription, OperatorGroup
│   │   └── instance/
│   │       ├── config.json
│   │       └── *.yaml              # QuayRegistry CR
│   ├── developer-hub/
│   │   ├── operator/
│   │   │   ├── config.json
│   │   │   └── *.yaml              # Subscription, OperatorGroup
│   │   └── instance/
│   │       ├── config.json
│   │       └── *.yaml              # Backstage CR, app-config
│   ├── dev-spaces/
│   │   ├── operator/
│   │   │   ├── config.json
│   │   │   └── *.yaml              # Subscription, OperatorGroup
│   │   └── instance/
│   │       ├── config.json
│   │       └── *.yaml              # CheCluster CR
│   ├── cert-manager/               # (optional)
│   │   ├── operator/
│   │   │   ├── config.json
│   │   │   └── *.yaml
│   │   └── instance/
│   │       ├── config.json
│   │       └── *.yaml              # ClusterIssuer
│   ├── external-secrets/           # (optional)
│   │   ├── operator/
│   │   │   ├── config.json
│   │   │   └── *.yaml
│   │   └── instance/
│   │       ├── config.json
│   │       └── *.yaml              # SecretStore
│   └── external-dns/               # (optional)
│       ├── operator/
│       │   ├── config.json
│       │   └── *.yaml
│       └── instance/
│           ├── config.json
│           └── *.yaml
```

---

## Phased Task List

### Phase 0 — Repo Scaffolding

- [x] Create the directory structure above
- [x] Add this PLAN.md

### Phase 1 — GitOps Bootstrap (Foundation)

This is the critical path — everything else depends on Argo CD being up and running.

- [x] **Ansible bootstrap playbook** (`ansible/bootstrap.yaml`)
  - Install the OpenShift GitOps operator (apply Subscription)
  - Wait for the operator to become ready
  - Apply the root Argo CD Application
- [x] **OpenShift GitOps operator manifests** (`components/openshift-gitops/operator/`)
  - Namespace, Subscription, OperatorGroup
- [x] **OpenShift GitOps instance** (`components/openshift-gitops/instance/`)
  - ArgoCD CR (customized instance config)
  - RBAC (ClusterRole, ClusterRoleBinding, cluster-admins Group)
- [x] **Root Application** — applied inline by bootstrap playbook; see [ADR-0002](decisions/0002-deploy-root-application-with-ansible.md)
- [x] **Operators ApplicationSet** (`bootstrap/operators-appset.yaml`)
  - Git files generator reading `config.json` from `components/*/operator/`
  - Each `config.json` declares `namespace` and optional `disabled`/`standalone` flags
  - Generates one Argo CD Application per operator, targeting the declared namespace
- [x] **Operands ApplicationSet** (`bootstrap/operands-appset.yaml`)
  - Git files generator reading `config.json` from `components/*/instance/`
  - Each `config.json` declares `namespace` and optional `disabled`/`standalone` flags
  - Generates one Argo CD Application per operand/service, targeting the declared namespace

### Phase 2 — Core Operators

Each operator just needs a Subscription and OperatorGroup in the appropriate namespace.

- [x] **OpenShift Pipelines** (`components/openshift-pipelines/operator/`)
- [x] **Quoay** (`components/quay/operator/`)
- [x] **Developer Hub** (`components/developer-hub/operator/`)
- [x] **Dev Spaces** (`components/dev-spaces/operator/`)

### Phase 3 — Core Operands

Custom Resources and configuration for each operator's managed service.

- [x] **OpenShift Pipelines** (`components/openshift-pipelines/instance/`)
  - No manifests required — operator auto-provisions `TektonConfig`, `TektonPipeline`, and `TektonTrigger` on install
- [x] **Quay** (`components/quay/instance/`)
  - QuayRegistry CR
- [ ] **Developer Hub** (`components/developer-hub/instance/`)
  - Backstage CR
  - app-config ConfigMap
- [x] **Dev Spaces** (`components/dev-spaces/instance/`)
  - CheCluster CR

### Phase 3.1 — Self-Hosted SCM (GitLab)

Required to complete Phase 3 — Developer Hub needs an on-cluster SCM for templates and catalog discovery.

  - OpenShift cert-manager operator + self-signed `ClusterIssuer`
- [x] **GitLab CE operator** (`components/gitlab/operator/`) — GitLab operator
  - See [ADR-0014](decisions/0014-gitlab-as-self-hosted-scm.md)
- [x] **GitLab CE instance** (`components/gitlab/instance/`) — GitLab CR (Community Edition)

### Phase 4 — Optional Org-Wide Services

These are not required for the core software factory but elevate the setup.

- [ ] **cert-manager ClusterIssuer upgrade** — replace `selfsigned-issuer` with ACME or Red Hat IdM issuer
- [ ] **external-secrets** — operator + SecretStore CR (for cert-manager and OAuth secrets)
- [ ] **external-dns** — operator + DNS config (works with cert-manager)
- [ ] **OAuth integration** — configure Developer Hub and Dev Spaces to use an external identity provider

### Phase 5 — Golden Path Template

A working end-to-end developer workflow: Developer Hub scaffolds a new application, Pipelines build and test it, Argo CD deploys it, and Dev Spaces provides a ready-to-code workspace. See [capabilities.md](capabilities.md) for the full rationale.

Source: adapted from [`rhpds/developer-hub-software-templates` `quarkus-web-template`](https://github.com/rhpds/developer-hub-software-templates/tree/main/scaffolder-templates/quarkus-web-template) — the only template in that repo with native `publish:gitlab` + Tekton + ArgoCD support. All other templates in that repo use `publish:github`. Template lives in this repo under `catalog/templates/quarkus-web-template/` and is registered in RHDH via a static catalog location; scaffolded repos are published to the on-cluster GitLab `software-factory` group.

- [ ] **Tekton Build & Push Pipeline** (`components/openshift-pipelines/instance/manifests/pipeline-build-push.yaml`)
  - Cluster-level `Pipeline` with tasks: `git-clone` → `buildah` (build OCI image) → push to Quay → `git-cli` write-back (update image tag in GitOps repo)
- [ ] **Software Template** (`catalog/templates/quarkus-web-template/`)
  - `template.yaml` — adapted from upstream: dynamic GitLab host, `openshift-gitops` ArgoCD namespace, Quay registry inputs
  - `skeleton/` — Quarkus starter source, `Containerfile`, `devfile.yaml`, `catalog-info.yaml`, `.tekton/pipeline.yaml` + `.tekton/pipelinerun.yaml`
  - No new RHDH plugins required — scaffolder actions used: `fetch:template` → `publish:gitlab` (source repo) → `fetch:template` → `publish:gitlab` (GitOps repo with ArgoCD `Application`) → `catalog:register`
- [ ] **RHDH catalog location** (`components/developer-hub/instance/manifests/app-config-rhdh.yaml`)
  - Add static location pointing to `catalog/templates/quarkus-web-template/catalog-info.yaml` in this repo so the template is available before any GitLab repos exist
- [ ] **Dev Spaces devfile** (`catalog/templates/quarkus-web-template/skeleton/devfile.yaml`)
  - UBI-based workspace image with common tooling, VS Code extensions (Java, Git, linting), Git remote pre-configured from scaffold inputs
- [ ] **Argo CD auto-deploy**
  - Template scaffolds a dedicated GitOps repo in GitLab with an ArgoCD `Application` manifest (Kustomize overlay per environment)
  - ArgoCD syncs it automatically via the existing `openshift-gitops` instance; no ApplicationSet changes needed

### Phase 6 — ACS Integration

Deploy Red Hat Advanced Cluster Security (ACS) and wire it into the CI/CD pipeline as a shift-left security gate. See [capabilities.md](capabilities.md).

- [ ] **ACS operator** (`components/acs/operator/`) — Subscription for `rhacs-operator` from `redhat-operators`
- [ ] **ACS instance** (`components/acs/instance/`) — `Central` CR deploying the ACS Central console
- [ ] **ACS `SecuredCluster`** — register the local cluster with ACS Central so runtime monitoring is active
- [ ] **Pipeline integration** — add a `roxctl image check` task to the Tekton golden path pipeline that fails the build if ACS reports policy violations on the built image
- [ ] **Deploy-time policy gate** — configure an ACS admission controller policy to block non-compliant images from being deployed to production namespaces

### Phase 7 — Stretch Goals

- [ ] **Red Hat IdM integration** — use IdM as both the certificate issuer and OAuth provider
- [ ] **Pluggable configuration** — Kustomize overlays or Helm values to support environment-specific tuning and make the repo more broadly applicable
