---
status: accepted
date: 2026-03-23
---

# Ignore Application Differences for syncPolicy and targetRevision

## Context and Problem Statement

Both ApplicationSets (`operators`, `operands`) template every generated Application with `syncPolicy.automated.selfHeal: true`. The ApplicationSet controller continuously reconciles generated Applications back to the template. This means any manual change to a generated Application — such as disabling automated sync to pause a rollout, or pinning `targetRevision` to a feature branch for PR testing — is immediately reverted by the controller.

## Decision Drivers

* Operators need to be able to pause automated sync on a single Application without affecting others
* PR and branch testing requires pointing an Application at a non-`main` revision without modifying git
* The ApplicationSet template (and therefore the default for all Applications) should remain unchanged

## Decision Outcome

Add `ignoreApplicationDifferences` to both ApplicationSets targeting the two fields most commonly overridden at runtime:

```yaml
ignoreApplicationDifferences:
  - jsonPointers:
    - /spec/syncPolicy/automated
    - /spec/source/targetRevision
```

The ApplicationSet controller will no longer revert manual changes to these two fields on any generated Application. All other template fields continue to be enforced normally.

### Consequences

* Good, because operators can disable automated sync on a single Application (e.g. to hold a deployment) without editing git or touching other Applications.
* Good, because a feature branch can be tested by patching `targetRevision` on one Application; the change persists until manually reverted.
* Bad, because drift in these fields is now silent — if `syncPolicy` or `targetRevision` are changed accidentally they will not be auto-corrected. Operators must remember to restore defaults after testing.
