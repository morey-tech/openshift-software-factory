---
status: accepted
date: 2026-03-21
---

# Use `manifests/` Subdirectory to Separate Generator Config from Synced Manifests

## Context and Problem Statement

The ApplicationSet Git Files Generator discovers components via `config.json` files (e.g., `components/*/operator/config.json`). The generator sets `{{ .path.path }}` to the directory containing the matched file, and both AppSets use this directly as `source.path`. This means ArgoCD syncs the same directory that holds `config.json` — and `config.json` has no `apiVersion`/`kind`, so ArgoCD fails with "Object 'Kind' is missing".

Two prior approaches were tried and failed:

- **ADR-0007** (`source.directory.exclude: "config.json"`): correctly excluded `config.json` from manifest processing, but setting `source.directory` locked every generated Application into plain directory mode, preventing Kustomize and Helm source auto-detection.
- **ADR-0008** (`.argocdignore` at repo root): based on incorrect information — `.argocdignore` is not a real ArgoCD feature and has no effect.

## Decision Drivers

* ArgoCD must not parse `config.json` as a Kubernetes manifest
* ArgoCD must auto-detect source type (directory, Kustomize, Helm) per component
* The Git Files Generator must continue to read `config.json` for `namespace`/`disabled` metadata
* The solution must require no special ArgoCD configuration

## Considered Options

* `source.directory.exclude: "config.json"` on both AppSets (ADR-0007 — superseded)
* `.argocdignore` at repo root (ADR-0008 — not a real feature)
* Move Kubernetes manifests into a `manifests/` subdirectory; point `source.path` to `{{ .path.path }}/manifests`

## Decision Outcome

Chosen option: `manifests/` subdirectory, because it structurally separates the generator config from the synced content. The Git Files Generator continues to find `config.json` at `components/*/operator/config.json`; `{{ .path.path }}` resolves to the `operator/` or `instance/` directory; and `source.path` is set to `{{ .path.path }}/manifests`, which never contains `config.json`. No special ArgoCD configuration is needed — Kustomize, Helm, and directory sources are all auto-detected based on what is inside `manifests/`.

### Consequences

* Good, because `config.json` is permanently outside the synced path with no per-component workarounds
* Good, because ArgoCD auto-detects source type per component (directory, Kustomize, Helm)
* Good, because no ArgoCD-specific configuration (e.g., `directory.exclude`) is required
* Bad, because every component now requires a `manifests/` subdirectory — new components must follow this convention

### Confirmation

After applying the change:
- No Application shows "Object 'Kind' is missing" errors
- `openshift-pipelines-operator` source type shows "Kustomize" in the ArgoCD UI
- `dev-spaces-instance` source type shows "Kustomize"
- Plain-directory components (`openshift-gitops-operator`, `openshift-gitops-instance`, `dev-spaces-operator`) sync correctly from their `manifests/` subdirectory

## Pros and Cons of the Options

### `manifests/` subdirectory

* Good, because structurally correct — generator config and Kubernetes manifests serve different purposes and belong at different paths
* Good, because source type auto-detection is fully preserved
* Good, because no ArgoCD configuration changes required
* Bad, because requires a `manifests/` directory in every component; adds one level of nesting

### `source.directory.exclude: "config.json"` (ADR-0007)

* Good, because no directory restructuring required
* Bad, because setting `source.directory` locks all Applications into directory mode
* Bad, because Kustomize and Helm components cannot be auto-detected

### `.argocdignore` at repo root (ADR-0008)

* Rejected — `.argocdignore` is not a documented or implemented ArgoCD feature
