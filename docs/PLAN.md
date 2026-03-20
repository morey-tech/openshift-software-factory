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

- [ ] Create the directory structure above
- [ ] Add this PLAN.md

### Phase 1 — GitOps Bootstrap (Foundation)

This is the critical path — everything else depends on Argo CD being up and running.

- [ ] **Ansible bootstrap playbook** (`ansible/playbook.yml`)
  - Install the OpenShift GitOps operator (apply Subscription)
  - Wait for the operator to become ready
  - Apply the root Argo CD Application
- [ ] **OpenShift GitOps operator manifests** (`components/openshift-gitops/operator/`)
  - Namespace, Subscription, OperatorGroup
- [ ] **OpenShift GitOps instance** (`components/openshift-gitops/instance/`)
  - ArgoCD CR (customized instance config)
  - RBAC (ClusterRoleBindings for Argo CD service accounts)
  - AppProject definitions
- [ ] **Root Application** (`bootstrap/root-application.yaml`)
  - Points at the `bootstrap/` directory in this repo
- [ ] **Operators ApplicationSet** (`bootstrap/operators-appset.yaml`)
  - Git files generator reading `config.json` from `components/*/operator/`
  - Each `config.json` declares `name` and `namespace` at minimum
  - Generates one Argo CD Application per operator, targeting the declared namespace
- [ ] **Operands ApplicationSet** (`bootstrap/operands-appset.yaml`)
  - Git files generator reading `config.json` from `components/*/instance/`
  - Each `config.json` declares `name` and `namespace` at minimum
  - Generates one Argo CD Application per operand/service, targeting the declared namespace

### Phase 2 — Core Operators

Each operator just needs a Subscription and OperatorGroup in the appropriate namespace.

- [ ] **OpenShift Pipelines** (`components/openshift-pipelines/operator/`)
- [ ] **Quay** (`components/quay/operator/`)
- [ ] **Developer Hub** (`components/developer-hub/operator/`)
- [ ] **Dev Spaces** (`components/dev-spaces/operator/`)

### Phase 3 — Core Operands

Custom Resources and configuration for each operator's managed service.

- [ ] **OpenShift Pipelines** (`components/openshift-pipelines/instance/`)
  - TektonConfig CR
  - Shared ClusterTasks / Pipelines (if any)
- [ ] **Quay** (`components/quay/instance/`)
  - QuayRegistry CR
- [ ] **Developer Hub** (`components/developer-hub/instance/`)
  - Backstage CR
  - app-config ConfigMap
- [ ] **Dev Spaces** (`components/dev-spaces/instance/`)
  - CheCluster CR

### Phase 4 — Optional Org-Wide Services

These are not required for the core software factory but elevate the setup.

- [ ] **cert-manager** — operator + ClusterIssuer CR
- [ ] **external-secrets** — operator + SecretStore CR (for cert-manager and OAuth secrets)
- [ ] **external-dns** — operator + DNS config (works with cert-manager)
- [ ] **OAuth integration** — configure Developer Hub and Dev Spaces to use an external identity provider

### Phase 5 — Stretch Goals

- [ ] **Red Hat IdM integration** — use IdM as both the certificate issuer and OAuth provider
- [ ] **Pluggable configuration** — Kustomize overlays or Helm values to support environment-specific tuning and make the repo more broadly applicable
