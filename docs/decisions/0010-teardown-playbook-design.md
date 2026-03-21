---
status: accepted
date: 2026-03-21
---

# Teardown Playbook Design: Rely on ArgoCD Cascade for Subscription Cleanup

## Context and Problem Statement

A teardown playbook is needed to reset the cluster to a clean state so bootstrapping can be repeated. The playbook must remove all resources installed by this project without hardcoding per-component details (Subscription names, CSV label selectors, etc.) that would need updating every time a new component is added.

## Decision Drivers

* The teardown should not be tightly coupled to individual component manifests
* Adding a new component should not require updating the teardown playbook
* The teardown must cleanly remove operators, including their CSVs, which OLM does not remove automatically

## Considered Options

* Hardcode each component's Subscription name and CSV label selector
* Rely on ArgoCD cascade delete for managed resources; handle only what ArgoCD cannot

## Decision Outcome

Chosen option: rely on ArgoCD cascade delete, because deleting the root `bootstrap` Application triggers the full chain: bootstrap → ApplicationSets → child Applications → all managed resources (Subscriptions, CheCluster, etc.). The root Application's `resources-finalizer.argocd.argoproj.io` does not resolve until the entire cascade is complete, so waiting for the Application to disappear proves all Subscriptions are deleted. The teardown then only handles what ArgoCD cannot:

1. **CSVs in `openshift-operators`** — created by OLM, not managed by ArgoCD; listed generically and deleted without hardcoding component names
2. **Project namespaces** — created via `CreateNamespace=true` and not tracked as managed resources; namespace termination cleans up all remaining resources including CSVs in dedicated namespaces (e.g. `openshift-gitops-operator`)

### Consequences

* Good, because adding a new component that installs into `openshift-operators` or a project namespace requires no teardown changes
* Good, because the playbook logic reflects the actual resource ownership (ArgoCD owns Subscriptions; OLM owns CSVs)
* Bad, because deleting all CSVs in `openshift-operators` will affect any other operators installed in that namespace on the same cluster — acceptable for the target demo/lab environment

### Confirmation

After running the teardown:
- No ArgoCD Applications remain in `openshift-gitops`
- No CSVs remain in `openshift-operators`
- Namespaces `openshift-gitops`, `openshift-gitops-operator`, and `openshift-devspaces` no longer exist

## Pros and Cons of the Options

### Hardcode each component's Subscription and CSV

* Good, because surgical — only removes exactly the resources this project installed
* Bad, because every new component requires a teardown update
* Bad, because names and label selectors must be kept in sync with component manifests

### ArgoCD cascade + generic CSV deletion

* Good, because decoupled — component additions do not require teardown changes
* Good, because ArgoCD's own cascade mechanism is used for what it manages
* Bad, because CSV deletion in `openshift-operators` is not scoped to this project's operators
