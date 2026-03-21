# Ansible Bootstrap

This directory contains the Ansible playbook used to bootstrap an empty OpenShift cluster by applying the root Argo CD Application, which triggers the App-of-Apps pattern to deploy everything else.

## Usage

```bash
ansible-playbook bootstrap.yaml
```

## Contents

| File | Purpose |
|------|---------|
| `bootstrap.yaml` | Playbook that applies the root Argo CD Application |
| `teardown.yaml` | Playbook that removes the root Application, GitOps operator, and associated namespaces to start fresh |
| `manifests/root-application.yaml` | Root Argo CD Application manifest — points at the `bootstrap/` directory in this repo |
