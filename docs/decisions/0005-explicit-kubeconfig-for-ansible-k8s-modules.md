---
status: accepted
date: 2026-03-21
---

# Explicit kubeconfig for Ansible kubernetes.core Modules

## Context and Problem Statement

When the bootstrap playbook is run from inside a DevSpaces workspace pod, the `kubernetes.core` Python client detects the `KUBERNETES_SERVICE_HOST` environment variable and automatically uses the pod's mounted service account token for authentication (in-cluster auth). This causes all tasks to run as the workspace service account (`system:serviceaccount:admin-devspaces:workspace...-sa`) rather than the cluster-admin user authenticated via `oc login`, resulting in 403 Forbidden errors.

## Decision Drivers

* The bootstrap playbook requires cluster-admin privileges not available to the workspace service account
* Authentication should be reproducible and explicit without requiring undocumented runtime environment setup
* The `oc login` workflow is the expected prerequisite for running the playbook

## Considered Options

* Use `module_defaults` in the playbook to explicitly set `kubeconfig` for all k8s tasks
* Set `K8S_AUTH_KUBECONFIG` environment variable at runtime (no playbook change)
* Grant the workspace service account cluster-admin privileges

## Decision Outcome

Chosen option: "Use `module_defaults` in the playbook", because it makes authentication explicit and reproducible for anyone running the playbook from a pod environment, without requiring undocumented environment variables or insecure RBAC grants.

The `module_defaults` block reads the `KUBECONFIG` env var (set by `oc` when using a non-default path) and falls back to `~/.kube/config`. It also disables TLS certificate verification by default (overridable via `K8S_AUTH_VERIFY_SSL=true`) to match the self-signed certificates common in sandbox/lab OpenShift clusters.

### Consequences

* Good, because authentication is explicit — the playbook behavior is predictable regardless of execution environment (local shell, DevSpaces pod, CI runner)
* Good, because `oc login` is the only prerequisite — no additional environment setup required
* Good, because `K8S_AUTH_VERIFY_SSL` allows cert validation to be enabled for production clusters
* Bad, because TLS validation is disabled by default, which is inappropriate for production use without setting `K8S_AUTH_VERIFY_SSL=true`

### Confirmation

Running `ansible-playbook bootstrap.yaml` from inside a DevSpaces workspace (after `oc login`) should authenticate as the `oc` user and succeed in creating namespaces and applying operator resources.

## Pros and Cons of the Options

### Use `module_defaults` in the playbook

* Good, because authentication is self-documenting and version-controlled in the playbook
* Good, because works in any execution environment without extra setup
* Bad, because adds boilerplate to the playbook

### Set `K8S_AUTH_KUBECONFIG` environment variable at runtime

* Good, because requires no playbook changes
* Bad, because undocumented — users must know to set this variable before running the playbook
* Bad, because does not solve the `validate_certs` issue separately

### Grant workspace service account cluster-admin privileges

* Bad, because it is a security risk — any pod in the workspace namespace gains cluster-admin
* Bad, because it does not generalize to other execution environments
