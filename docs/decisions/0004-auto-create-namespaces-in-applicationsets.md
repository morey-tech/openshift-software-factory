---
status: accepted
date: 2026-03-20
---

# Auto-Create Namespaces in ApplicationSets

## Context and Problem Statement

Components deployed by the ApplicationSets target namespaces that may or may not already exist on the cluster. Some operators require dedicated namespaces that don't exist by default (e.g. `openshift-gitops-operator`), while others deploy into shared namespaces like `openshift-operators` that already exist. We cannot include Namespace manifests in every component folder because creating a Namespace that is shared by multiple components would cause sync conflicts — multiple Applications would fight over the same resource.

## Decision Drivers

* Components may target namespaces that don't exist yet on a fresh cluster
* Some namespaces are shared across components — including Namespace manifests in each would cause ownership conflicts
* The solution should work without requiring a specific deployment order

## Considered Options

* Include Namespace manifests in each component folder
* Auto-create namespaces via `CreateNamespace=true` sync option

## Decision Outcome

Chosen option: "Auto-create namespaces via `CreateNamespace=true`", because it handles both cases cleanly. If the namespace already exists (shared namespaces like `openshift-operators`), the sync proceeds normally. If it doesn't exist (dedicated namespaces), Argo CD creates it automatically before syncing the resources.

This is set on both the `operators` and `operands` ApplicationSet templates via:

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
```

### Consequences

* Good, because components don't need Namespace manifests — no ownership conflicts on shared namespaces
* Good, because deployment order doesn't matter — the namespace is created on demand
* Good, because it works transparently for both existing and new namespaces
* Neutral, because auto-created namespaces are basic — any namespace customisation (labels, annotations) would need a separate mechanism
