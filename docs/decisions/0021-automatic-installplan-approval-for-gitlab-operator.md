---
status: accepted
date: 2026-03-23
---

# Automatic InstallPlan Approval for GitLab Operator

## Context and Problem Statement

The GitLab Operator Subscription previously used `installPlanApproval: Manual`, following GitLab's OpenShift recommendation to prevent unintended operator upgrades. However, OLM requires a human (or a dedicated controller) to manually approve the generated InstallPlan before the operator is installed. During a fully automated bootstrap via Argo CD, no such approval happens, so the operator never installs and the entire GitLab component remains broken until someone manually approves the InstallPlan in the console or via `oc`.

## Decision Drivers

* Bootstrap must complete without manual intervention
* Operator upgrades must not break the deployed GitLab instance
* The solution must stay within the existing OLM + Argo CD toolchain

## Considered Options

* **`installPlanApproval: Manual`** — safe against upgrades but blocks automated bootstrap
* **`installPlanApproval: Automatic`** — allows unattended install; upgrade risk mitigated by pinning the chart version in the GitLab CR

## Decision Outcome

Chosen option: **`installPlanApproval: Automatic`**, because it allows the bootstrap playbook and Argo CD sync to complete without human intervention while the upgrade risk is already managed by pinning `spec.chart.values.global.operator.version` (or equivalent) in the GitLab CR. OLM upgrading the operator does not redeploy the GitLab instance; the CR controls which chart version is applied.

### Consequences

* Good, because bootstrap is fully automated — no InstallPlan approval step required.
* Good, because the GitLab chart version is decoupled from the operator version via the GitLab CR, so an operator upgrade does not change the running instance.
* Bad, because a new operator version could introduce a breaking API change that affects the GitLab CR. This risk is accepted given that OLM upgrades within a channel are expected to be backwards-compatible.

### Confirmation

After a clean bootstrap, verify the operator installed without manual approval:

```bash
oc get installplan -n gitlab-system
# All InstallPlans should show APPROVED: true
oc get csv -n gitlab-system
# CSV should reach phase: Succeeded
```
