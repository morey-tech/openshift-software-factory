---
status: accepted
date: 2026-03-20
---

# Support Disabling Components via config.json

## Context and Problem Statement

Some components included in the software factory may already be deployed in a given OpenShift cluster by other means (e.g. managed by a different team, installed manually, or provided by the cluster platform). The ApplicationSets should be able to skip these components without removing their manifests from the repo.

## Decision Drivers

* Components already managed outside this repo should not be double-deployed
* Disabling a component should be simple and obvious — no need to delete files or restructure folders
* The mechanism should be safe by default — components are enabled unless explicitly disabled

## Considered Options

* Remove the component folder entirely when not needed
* Use a separate list of enabled/disabled components in the ApplicationSet
* Add a `disabled` flag in the component's `config.json` with a post selector

## Decision Outcome

Chosen option: "Add a `disabled` flag in config.json with a post selector", because it keeps the decision co-located with the component and is safe by default.

Each ApplicationSet uses a post selector to filter out components where `disabled` is `"true"`:

```yaml
selector:
  matchExpressions:
    - key: disabled
      operator: NotIn
      values:
        - "true"
```

To disable a component, set `disabled` to `"true"` in its `config.json`:

```json
{
  "namespace": "openshift-operators",
  "disabled": "true"
}
```

The `NotIn` operator (rather than `DoesNotExist`) means that `disabled: "false"` or omitting the field entirely both result in the component being enabled. Only an explicit `"true"` disables it.

### Consequences

* Good, because components are enabled by default — no flag needed for the common case
* Good, because the disable decision lives next to the component's manifests, not in a centralized list
* Good, because component manifests remain in the repo for reference even when disabled
* Neutral, because `disabled: "false"` and omitting the field are both valid ways to enable a component
