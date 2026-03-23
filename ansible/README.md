# Ansible Bootstrap

This directory contains the Ansible playbooks used to bootstrap and tear down an OpenShift cluster running the Software Factory.

## Prerequisites

Before running either playbook, ensure:

1. **Cluster access** — the `oc` CLI must be authenticated against the target cluster, or `KUBECONFIG` must be set. Both playbooks use the active cluster context; no inventory or SSH is involved.
2. **Cluster requirements** — the cluster must satisfy all prerequisites described in [docs/prerequisites.md](../docs/prerequisites.md) (storage class, object storage, cert-manager, and Ansible dependencies).

## Usage

Bootstrap the cluster:

```bash
ansible-playbook bootstrap.yaml
```

Reset to a clean state:

```bash
ansible-playbook teardown.yaml
```

Run teardown before bootstrap to start fresh — teardown fully waits for all namespaces to terminate before exiting.

## Contents

| File | Purpose |
|------|---------|
| `bootstrap.yaml` | Installs the GitOps operator, applies the ArgoCD instance and standalone Application, then applies the root `bootstrap` Application |
| `teardown.yaml` | Deletes the root Application (cascade), the standalone `openshift-gitops-instance` Application, project CSVs, and project namespaces in the correct order |
