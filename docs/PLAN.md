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

Source: adapted from [`rhpds/developer-hub-software-templates` `quarkus-web-template`](https://github.com/rhpds/developer-hub-software-templates/tree/main/scaffolder-templates/quarkus-web-template) — the only template in that repo with native `publish:gitlab` + Tekton + ArgoCD support. All other templates in that repo use `publish:github`. Template lives in this repo under `catalog/templates/quarkus-web-template/` and is registered in RHDH via a static catalog location; scaffolded repos are published to the on-cluster GitLab `software-factory` group. No new RHDH plugins required — only built-in scaffolder actions (`fetch:template`, `publish:gitlab`, `catalog:register`).

**GitLab group structure used by Phase 5:**
```
software-factory/          ← top-level group; RHDH gitlabOrg discovery targets this
├── platform/              ← subgroup for platform-owned repos (catalog, shared config)
│   └── software-factory-catalog   ← repo: catalog-info.yaml for the template; RHDH discovers it automatically
└── apps/                  ← subgroup for repos scaffolded by the golden path template
    ├── my-app             ← source repo (created by template)
    └── my-app-gitops      ← gitops repo (created by template; ArgoCD watches this)
```

#### 5.0 — GitLab Group Initialization Job
*Prerequisite for all other Phase 5 tasks. Depends on GitLab instance running and root password Secret existing (Phase 3.1).*
- [x] Create `components/gitlab/instance/manifests/gitlab-group-init-job.yaml` (ServiceAccount, Role, RoleBinding, ConfigMap with script, Job)
  - Sync wave `1` — runs after GitLab CR is `Running` (wave `0`) and root password Secret exists (wave `-1`)
  - Script polls GitLab health, then uses the root PAT from `rhdh-secrets` (or reads `gitlab-initial-root-password` directly) to call the GitLab API:
    - `POST /api/v4/groups` — create `software-factory` group (idempotent: skip if already exists)
    - `POST /api/v4/groups` — create `software-factory/platform` subgroup
    - `POST /api/v4/groups` — create `software-factory/apps` subgroup
    - `POST /api/v4/projects` — create `platform/software-factory-catalog` repo with a seed `catalog-info.yaml` that registers the golden path template

#### 5.1 — Tekton Build & Push Pipeline
*No dependencies — can be implemented first.*
- [x] Create `components/openshift-pipelines/instance/manifests/pipeline-build-push.yaml`
  - Cluster-scoped `Pipeline` named `build-and-push`
  - Tasks in order: `git-clone` → `buildah` (build + push OCI image to Quay) → `git-cli` (write image digest back to GitOps repo)
  - Workspace bindings: shared source workspace, Quay push secret, GitLab SSH/token for write-back

#### 5.2 — App Source Skeleton
*No dependencies — can be implemented in parallel with 5.1.*
- [x] Create `catalog/templates/quarkus-web-template/skeleton/` source files:
  - `pom.xml` — Quarkus BOM, `quarkus-resteasy-reactive` starter dependency
  - `src/main/java/.../GreetingResource.java` — minimal REST endpoint
  - `src/main/resources/application.properties` — Quarkus config (port, health endpoint)
  - `Containerfile` — multi-stage build: Maven compile → UBI minimal runtime image
  - `.gitignore`, `README.md`

#### 5.3 — App Dev Spaces Devfile
*No dependencies — can be implemented in parallel with 5.1 and 5.2.*
- [x] Create `catalog/templates/quarkus-web-template/skeleton/devfile.yaml`
  - Base image: Red Hat Dev Spaces UDI see devfile.yaml
  - Components: main dev container + volume mount for Maven cache
  - Commands: `mvn quarkus:dev` for hot-reload, `mvn package` for build
  - Git remote pre-wired via template variable `${{ values.repoUrl }}`

#### 5.4 — App Tekton Skeleton
*Depends on 5.1 (pipeline name `build-and-push` must be known).*
- [x] Create `catalog/templates/quarkus-web-template/skeleton/.tekton/pipelinerun.yaml`
  - References the cluster `Pipeline` `build-and-push` by name
  - Params: image name (`quay.io/${{ values.quayNamespace }}/${{ values.name }}`), GitOps repo URL
  - Workspace references: PVC for source, secret refs for Quay and GitLab credentials

#### 5.5 — App Catalog Metadata Skeleton
*No dependencies.*
- [x] Create `catalog/templates/quarkus-web-template/skeleton/catalog-info.yaml`
  - `kind: Component`, `type: service`, `lifecycle: experimental`
  - Backstage template variables: `${{ values.name }}`, `${{ values.owner }}`, `${{ values.system }}`
  - Annotations: ArgoCD app link, Tekton pipeline link, GitLab source URL, Dev Spaces workspace URL

#### 5.6 — GitOps Repo Skeleton
*No dependencies — defines the ArgoCD Application and Kustomize manifests for the scaffolded app.*
- [ ] Create `catalog/templates/quarkus-web-template/gitops-skeleton/`:
  - `base/deployment.yaml` — Deployment with image placeholder (`image: PLACEHOLDER`)
  - `base/service.yaml` — ClusterIP Service
  - `base/kustomization.yaml` — lists base resources
  - `overlays/dev/kustomization.yaml` — patches image tag, sets namespace `${{ values.name }}-dev`
  - `argocd-application.yaml` — ArgoCD `Application` targeting `overlays/dev`, namespace `openshift-gitops`, project `operands`

#### 5.7 — Template Catalog-Info & template.yaml
*Depends on 5.2–5.6 (skeleton content and gitops-skeleton must be defined so template steps can reference them).*
- [ ] Create `catalog/templates/quarkus-web-template/catalog-info.yaml`
  - `kind: Template`, registers with RHDH
  - Points to `template.yaml` in the same directory
  - This file is also pushed to `software-factory/platform/software-factory-catalog` by the 5.0 job so RHDH's gitlabOrg discovery picks it up automatically
- [ ] Create `catalog/templates/quarkus-web-template/template.yaml`
  - User inputs: `name`, `description`, `owner`, `system`, `quayNamespace`
  - Source repo destination: `software-factory/apps/${{ parameters.name }}` (group fixed; no user input)
  - GitOps repo destination: `software-factory/apps/${{ parameters.name }}-gitops`
  - GitLab host: `${GITLAB_HOST}` env var injected from `rhdh-secrets` — no user input required
  - Steps:
    1. `fetch:template` → source skeleton
    2. `publish:gitlab` → push source repo to `software-factory/apps/${{ parameters.name }}`
    3. `fetch:template` → GitOps skeleton
    4. `publish:gitlab` → push GitOps repo to `software-factory/apps/${{ parameters.name }}-gitops`
    5. `catalog:register` → register `catalog-info.yaml` from source repo

#### 5.8 — RHDH Catalog Location
*Depends on 5.0 (GitLab `platform/software-factory-catalog` repo must exist) and 5.7 (catalog-info.yaml authored).*
- [ ] Modify `components/developer-hub/instance/manifests/app-config-rhdh.yaml`
  - Populate `catalog.locations` with a static entry pointing to the GitLab catalog repo:
    ```yaml
    - type: url
      target: https://gitlab.${APPS_DOMAIN}/software-factory/platform/software-factory-catalog/-/raw/main/catalog-info.yaml
    ```
  - The `APPS_DOMAIN` variable is already injected from `rhdh-secrets`
  - The 5.0 job seeds this repo at deploy time, so the template is discoverable as soon as RHDH starts

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
