# Ansible Bootstrap

This directory contains the Ansible playbook and roles used to bootstrap an empty OpenShift cluster with the GitOps operator and the root Argo CD Application.

## Usage

```bash
ansible-playbook -i inventory playbook.yml
```

## What the Bootstrap Does

1. Installs the OpenShift GitOps operator (Subscription)
2. Waits for the operator to become ready
3. Applies the root Argo CD Application, which triggers the App-of-Apps pattern to deploy everything else
