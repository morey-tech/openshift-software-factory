# Components

Each subdirectory represents a platform component with two folders:

- `operator/` — OLM manifests (Subscription, OperatorGroup) to install the operator
- `instance/` — Custom Resources and configuration to deploy the operand/service

Each `operator/` and `instance/` folder contains a `config.json` that declares the Application name and target namespace for the ApplicationSet generator.

## Core Components

| Component | Description |
|-----------|-------------|
| `openshift-gitops` | Argo CD — GitOps engine |
| `openshift-pipelines` | Tekton — CI/CD pipelines |
| `quay` | Container image registry |
| `developer-hub` | Backstage — developer portal |
| `dev-spaces` | Cloud-based IDE workspaces |

## Optional Components

| Component | Description |
|-----------|-------------|
| `cert-manager` | TLS certificate management |
| `external-secrets` | Secrets from external stores |
| `external-dns` | Automated DNS management |
