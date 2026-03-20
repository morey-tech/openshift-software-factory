# Enterprise Software Factory — Project Plan

This document outlines the work required to build out this repository with all the OpenShift manifests and automation needed to bootstrap an empty cluster into a fully functional software factory.

## Architecture Overview

```
Ansible Playbook
  └── Installs OpenShift GitOps Operator
        └── Creates Root Argo CD Application
              └── Deploys 2 ApplicationSets
                    ├── Operators AppSet  → scans components/*/operator/
                    └── Operands AppSet   → scans components/*/instance/
```

Adding a new component = add a folder under `components/` with `operator/` and/or `instance/` subdirectories. The ApplicationSets automatically pick it up.

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
│   ├── operators-appset.yaml       # ApplicationSet: components/*/operator/
│   └── operands-appset.yaml        # ApplicationSet: components/*/instance/
├── components/
│   ├── openshift-gitops/
│   │   ├── operator/               # Subscription, OperatorGroup
│   │   └── instance/               # ArgoCD CR, RBAC, AppProjects
│   ├── openshift-pipelines/
│   │   ├── operator/               # Subscription, OperatorGroup
│   │   └── instance/               # TektonConfig, shared Tasks/Pipelines
│   ├── quay/
│   │   ├── operator/               # Subscription, OperatorGroup
│   │   └── instance/               # QuayRegistry CR
│   ├── developer-hub/
│   │   ├── operator/               # Subscription, OperatorGroup
│   │   └── instance/               # Backstage CR, app-config
│   ├── dev-spaces/
│   │   ├── operator/               # Subscription, OperatorGroup
│   │   └── instance/               # CheCluster CR
│   ├── cert-manager/               # (optional)
│   │   ├── operator/
│   │   └── instance/               # ClusterIssuer
│   ├── external-secrets/           # (optional)
│   │   ├── operator/
│   │   └── instance/               # SecretStore
│   └── external-dns/               # (optional)
│       ├── operator/
│       └── instance/
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
  - Git directory generator scanning `components/*/operator/`
  - Generates one Argo CD Application per operator
- [ ] **Operands ApplicationSet** (`bootstrap/operands-appset.yaml`)
  - Git directory generator scanning `components/*/instance/`
  - Generates one Argo CD Application per operand/service

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
