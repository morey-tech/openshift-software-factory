# Bootstrap

This directory contains the root Argo CD Application and the two ApplicationSets that drive the App-of-Apps pattern.

## Contents

| File | Purpose |
|------|---------|
| `root-application.yaml` | Root Argo CD Application — points at this directory |
| `operators-appset.yaml` | ApplicationSet using git files generator to discover `components/*/operator/config.json` |
| `operands-appset.yaml` | ApplicationSet using git files generator to discover `components/*/instance/config.json` |

Each ApplicationSet reads `config.json` files from component folders to determine the Application name, target namespace, and source path.
