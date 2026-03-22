---
status: accepted
date: 2026-03-22
---

# Deploy Developer Hub Instance in a Dedicated `rhdh` Namespace

## Context and Problem Statement

The Red Hat Developer Hub operator is installed in the `rhdh-operator` namespace. When deploying the Backstage CR (the actual Developer Hub instance), which namespace should it target?

## Decision Drivers

* Consistent with how other operator/instance pairs are structured in this repository
* Separation of operator lifecycle management from application workloads
* Namespace naming should be intuitive and distinct from the operator namespace

## Decision Outcome

Chosen option: **Deploy the Backstage CR to the `rhdh` namespace**, separate from the `rhdh-operator` operator namespace.

The `components/developer-hub/instance/config.json` declares `"namespace": "rhdh"`, and the `operands` ApplicationSet creates the namespace automatically via `CreateNamespace=true`.

### Consequences

* Good, because consistent with the established pattern: CheCluster lives in `openshift-devspaces` (not `openshift-operators`), QuayRegistry lives in `quay-operator` but is distinct from the operator install namespace in intent.
* Good, because operator upgrades in `rhdh-operator` do not affect the instance namespace directly.
* Good, because namespace-scoped RBAC and resource quotas can be applied to `rhdh` independently.
* Neutral, because the RHDH operator watches Backstage CRs across all namespaces by default, so no additional configuration is needed.

### Confirmation

Confirmed when `oc get backstage developer-hub -n rhdh` exists and `oc get route -n rhdh` returns the Developer Hub URL.
