# Bootstrap

This directory contains the two ApplicationSets that drive the App-of-Apps pattern. It is targeted by the root Argo CD Application, which is applied externally via the [Ansible bootstrap playbook](../ansible/bootstrap.yaml).

## Contents

| File | Purpose |
|------|---------|
| `operators-appset.yaml` | ApplicationSet using git files generator to discover `components/*/operator/config.json` |
| `operands-appset.yaml` | ApplicationSet using git files generator to discover `components/*/instance/config.json` |

Each ApplicationSet reads `config.json` files from component folders to determine the Application name, target namespace, and source path.
