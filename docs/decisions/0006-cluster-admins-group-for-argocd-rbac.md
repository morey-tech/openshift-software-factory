---
status: accepted
date: 2026-03-21
---

# Use cluster-admins Group for Argo CD Admin Access

## Context and Problem Statement

The Argo CD instance uses Dex with OpenShift OAuth for SSO. Dex surfaces group memberships as claims, but does not surface direct `ClusterRoleBinding` assignments — meaning individual users cannot be mapped to Argo CD roles by username. The default `admin` user on the Red Hat Demo Platform is not a member of any group, so the admin user had no way to access Argo CD with admin privileges.

## Decision Drivers

* Argo CD RBAC with Dex only supports group-based role mappings, not individual user mappings
* The `admin` user on the Red Hat Demo Platform has no group memberships by default
* The solution should be declarative and managed by GitOps

## Considered Options

* Map `g, admin, role:admin` directly in the Argo CD RBAC policy
* Create a `cluster-admins` group, add the admin user to it, and map the group to the Argo CD admin role

## Decision Outcome

Chosen option: "Create a `cluster-admins` group", because Dex does not surface individual usernames as role-mappable subjects — only group claims are supported. Mapping `g, admin, role:admin` has no effect.

The `cluster-admins` group is created by the bootstrap playbook (since the admin user must exist before GitOps can manage the resource). A `ClusterRoleBinding` grants the group the `cluster-admin` ClusterRole on the cluster, and the Argo CD RBAC policy maps `cluster-admins` to `role:admin`.

### Consequences

* Good, because only explicitly added users have Argo CD admin access
* Good, because the group membership is declarative and version-controlled
* Bad, because the group membership must be updated manually when the admin user changes (e.g., on a new demo cluster)

### Confirmation

After running the bootstrap playbook, `oc get group cluster-admins -o yaml` should show the `admin` user as a member. Logging into the Argo CD UI via OpenShift OAuth as `admin` should grant admin access.

## Pros and Cons of the Options

### Map `g, admin, role:admin` directly in the Argo CD RBAC policy

* Good, because it requires no group management
* Bad, because Dex does not surface individual usernames — the mapping has no effect

### Create a `cluster-admins` group

* Good, because compatible with Dex group-based role mapping
* Good, because access is scoped to an explicit, managed group
* Good, because the group and ClusterRoleBinding are declarative and GitOps-managed
* Bad, because requires the bootstrap playbook to create the group before Argo CD is available
