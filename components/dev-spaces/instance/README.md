# Dev Spaces — Instance

This folder is managed by the `operands` ApplicationSet.

## Contents

| File | Purpose |
|------|---------|
| `config.json` | Declares the target namespace (`openshift-devspaces`) for the Argo CD Application |
| `manifests/kustomization.yaml` | Kustomize overlay targeting `openshift-devspaces` namespace |
| `manifests/checluster.yaml` | CheCluster CR — core Dev Spaces configuration |
| `manifests/vscode-editor-configurations.yaml` | ConfigMap with VS Code editor settings and recommended extensions |

## CheCluster Configuration

Key settings in `checluster.yaml`:

- **Plugin registry:** Open VSX (`https://open-vsx.org`)
- **Workspace limits:** Unlimited per user and per cluster
- **Storage:** `per-workspace` PVC strategy with 5Gi per workspace

Reference: [CheCluster Custom Resource Fields](https://docs.redhat.com/en/documentation/red_hat_openshift_dev_spaces/3.24/html/administration_guide/configuring-devspaces#checluster-custom-resource-fields-reference)

## VS Code Editor Configurations

The `vscode-editor-configurations` ConfigMap is deployed to `openshift-devspaces` and automatically replicated to all user workspace namespaces by the DevWorkspace controller. It configures:

- Roo Code auto-import settings path
- Recommended extensions (Roo Code, Markdown All in One, OpenShift Connector)

Reference: [Editor Configurations for VS Code](https://docs.redhat.com/en/documentation/red_hat_openshift_dev_spaces/3.25/html/administration_guide/configuring-visual-studio-code#editor-configurations-for-microsoft-visual-studio-code)
