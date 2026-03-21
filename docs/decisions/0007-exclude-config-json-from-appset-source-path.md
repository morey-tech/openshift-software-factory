---
status: superseded by [ADR-0009](0009-manifests-subdirectory-for-appset-source-path.md)
date: 2026-03-21
---

# Exclude config.json from ApplicationSet Source Paths

## Context and Problem Statement

The `operators` and `operands` ApplicationSets use a Git Files Generator to discover components via `config.json` files. The generated Application's `source.path` resolves to the directory containing the `config.json` (e.g., `components/openshift-gitops/operator/`). ArgoCD attempts to parse every file in that directory as a Kubernetes manifest, causing a parse error for `config.json` because it has no `apiVersion` or `kind`.

## Decision Drivers

* `config.json` is a generator configuration file, not a Kubernetes manifest
* ArgoCD fails to load target state when it encounters non-manifest files in the source path
* The fix must not affect how the Git Files Generator discovers components

## Considered Options

* Set `directory.exclude: "config.json"` in the ApplicationSet source template
* Move `config.json` to a subdirectory outside the synced path (e.g., a `.appset/` subfolder)
* Rename `config.json` with a non-YAML/JSON extension that ArgoCD ignores

## Decision Outcome

Chosen option: `directory.exclude: "config.json"`, because it is the most direct fix with no structural changes to the repository. ArgoCD's `directory.exclude` glob filter prevents `config.json` from being processed as a manifest while the Git Files Generator continues to read it normally.

### Consequences

* Good, because no repository structure changes are required
* Good, because the exclusion is explicit and co-located with the source definition
* Bad, because the exclusion must be remembered if new ApplicationSets are added with the same pattern

### Confirmation

After applying the change, the `openshift-gitops-operator` and `openshift-gitops-instance` ArgoCD Applications should sync successfully without the "Object 'Kind' is missing" error.
