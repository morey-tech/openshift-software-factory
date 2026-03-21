---
status: accepted
date: 2026-03-21
---

# Quay Registry Component Configuration

## Context and Problem Statement

The QuayRegistry custom resource exposes a `spec.components` list that controls which sub-services the Quay Operator provisions and manages. Each component can be set to `managed: true` (operator-provisioned) or `managed: false` (externally supplied). The software factory needs a container registry that build pipelines can push images to, the OpenShift cluster can pull images from, and that integrates with the planned ACS security gate. Which components should be managed by the operator, and which (if any) should be left unmanaged?

## Decision Drivers

* The target cluster is the Red Hat Demo Platform, which provides ODF/NooBaa and a default StorageClass — no external object storage or database needs to be pre-provisioned
* Operational simplicity: fewer external dependencies mean less setup and teardown complexity
* Security: image vulnerability scanning is a planned Phase 6 requirement (ACS pipeline gate); enabling it at the registry level is preferable to bolting it on later
* Repository mirroring is not a use case — images are produced and pushed by Tekton pipelines, not mirrored from upstream registries

## Considered Options

* **All components managed** — operator provisions every sub-service (Postgres, Redis, Clair, object storage, route, TLS, HPA, monitoring)
* **Managed with `mirror` disabled** — same as above but explicitly disable the mirroring component as it is unused overhead
* **Unmanaged storage** — bring an external S3-compatible bucket and configure it via a `configBundleSecret`
* **Unmanaged Postgres** — bring an external PostgreSQL instance

## Decision Outcome

Chosen option: **Managed with `mirror` disabled**, because it maximises operator-managed simplicity while avoiding provisioning a component that serves no purpose in this architecture.

### Consequences

* Good, because the operator handles all lifecycle management (upgrades, config, scaling) for Postgres, Redis, Clair, and object storage
* Good, because `objectstorage: managed: true` causes the operator to create an `ObjectBucketClaim` that NooBaa satisfies automatically — no manual S3 bucket or credential management required
* Good, because Clair vulnerability scanning is available immediately, providing image security data in the Quay UI and enabling the Phase 6 ACS pipeline integration without additional configuration
* Good, because HPA is enabled so the registry scales under burst load from parallel pipeline runs
* Bad, because managed Postgres and Redis are single-replica deployments not suitable for high-availability production; an unmanaged HA database would be required for a production hardening scenario
* Bad, because all components managed means a larger initial footprint on the cluster

### Confirmation

After deploying the QuayRegistry CR, confirm with:
```bash
oc get quayregistry registry -n quay-operator -o jsonpath='{.status.conditions}'
oc get pods -n quay-operator
oc get objectbucketclaim -n quay-operator
```
All pods should be Running and the `QuayRegistry` status condition `Available` should be `True`.

## Pros and Cons of the Options

### All components managed

* Good, because simplest configuration — no external infrastructure to provision
* Good, because operator manages upgrades for all sub-services
* Bad, because provisions `mirror` (repository mirroring) even though it is unused in this architecture

### Managed with `mirror` disabled

* Good, because avoids creating unused mirror worker pods and associated resources
* Good, because explicitly documents the intent that mirroring is not part of this architecture
* Neutral, because all other components remain fully managed

### Unmanaged storage

* Good, because allows use of high-performance or HA-class S3 object storage
* Bad, because requires a `configBundleSecret` and manual bucket provisioning — adds operational complexity
* Bad, because breaks the GitOps-only deployment model (secrets must be pre-provisioned out-of-band)

### Unmanaged Postgres

* Good, because enables HA database configuration (e.g., Patroni, CrunchyDB)
* Bad, because requires an external database cluster and a `configBundleSecret`
* Bad, because out of scope for a demo-platform deployment
