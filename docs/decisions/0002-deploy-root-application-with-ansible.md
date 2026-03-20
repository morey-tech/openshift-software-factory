---
status: accepted
date: 2026-03-20
---

# Deploy Root Argo CD Application with Ansible

## Context and Problem Statement

The root Argo CD Application drives the App-of-Apps pattern by pointing at the `bootstrap/` directory, which contains the two ApplicationSets. If the root Application manifest lives inside `bootstrap/`, Argo CD manages the Application that created it — a circular dependency where the Application syncs itself.

## Decision Drivers

* The root Application must not be managed by itself
* The bootstrap process should be reproducible and automated
* The solution should be simple and not require additional tooling

## Considered Options

* Place the root Application in the `bootstrap/` directory (self-managed)
* Apply the root Application via an Ansible playbook

## Decision Outcome

Chosen option: "Apply the root Application via an Ansible playbook", because it breaks the circular dependency cleanly. The Ansible playbook (`ansible/bootstrap.yaml`) applies the root Application manifest (`ansible/manifests/root-application.yaml`) using `kubernetes.core.k8s`. Once applied, Argo CD takes over and manages everything inside `bootstrap/` without managing itself.

### Consequences

* Good, because the root Application is not self-referential — no circular dependency
* Good, because the bootstrap is a single `ansible-playbook` command, making it reproducible
* Good, because the root Application manifest is still version-controlled in the repo, just outside the Argo CD-managed path
* Neutral, because Ansible and the `kubernetes.core` collection are required to bootstrap the cluster
