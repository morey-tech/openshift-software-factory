---
status: accepted
date: 2026-03-25
---

# Quay Resource Overrides to Prevent Pod Scheduling Starvation on Demo Cluster

## Context and Problem Statement

After deploying the QuayRegistry with all components managed, the Quay Operator provisioned
resource requests that starved other workloads on the demo cluster. Inspection of the
`quay-operator` namespace revealed:

| Component | Replicas | CPU Request | Total |
|-----------|----------|-------------|-------|
| `clair-app` | 10 (HPA) | 2 cores each | **20 cores** |
| `quay-app`  | 2        | 2 cores each | 4 cores |
| `clair-postgres` / `quay-database` / `redis` | 1 each | 500m each | 1.5 cores |

The HPA for Clair scaled to 10 replicas at 2 cores each, reserving ~25 cores in total across
Quay alone and preventing other pods from being scheduled.

## Decision Drivers

* The target cluster is the Red Hat Demo Platform, a shared, capacity-constrained environment
  — not a production cluster sized for high availability
* Other software factory components (GitLab, RHDH, Tekton, ACS) must be schedulable alongside Quay
* Clair is used for vulnerability scan results only; low replica count does not affect pipeline
  correctness, only scan throughput
* The quay-app default request of 2 cores is sized for production concurrency; demo pipeline
  load is much lower

## Considered Options

* **Resource overrides via `spec.components[].overrides`** — reduce CPU requests and cap Clair replicas in the QuayRegistry CR
* **Unmanage Clair** — set `clair: managed: false` to remove it entirely
* **Scale the cluster** — add more worker nodes to absorb the default requests

## Decision Outcome

Chosen option: **Resource overrides via `spec.components[].overrides`**, because it keeps all
components managed (preserving the operator lifecycle benefits from ADR-0012) while right-sizing
requests for the demo environment. Unmanaging Clair would lose vulnerability scan data needed
for the Phase 6 ACS pipeline gate. Scaling the cluster is out of scope for the demo platform.

The following overrides are applied:

| Component | Override | Value | Rationale |
|-----------|----------|-------|-----------|
| `quay` | `resources.requests.cpu` | `500m` | Default 2 cores is production-sized; 500m is sufficient for demo pipeline throughput |
| `quay` | `resources.requests.memory` | `2Gi` | Retain operator default to avoid OOMKill |
| `clair` | `resources.requests.cpu` | `100m` | Clair scans are background/async; low request keeps HPA scale-out conservative vs the 2-core default that drove 10 replicas |
| `clair` | `resources.requests.memory` | `512Mi` | Reduced from 2Gi default; sufficient for CVE database and scan queue at low concurrency |

### Consequences

* Good, because total Quay CPU reservation drops from ~25 cores to ~1.7 cores, freeing
  capacity for other software factory workloads
* Good, because all components remain managed — operator still handles upgrades, config, and
  Clair CVE feed synchronisation
* Bad, because Clair scan throughput is reduced; concurrent vulnerability scans may queue under
  heavy pipeline load
* Bad, because these overrides diverge from operator defaults and must be re-evaluated if the
  deployment is ever promoted to a production environment

### Confirmation

After ArgoCD syncs the updated QuayRegistry, confirm with:

```bash
oc get pods -n quay-operator -o json | \
  jq -r '.items[] | .metadata.name as $pod | .spec.containers[] |
    [$pod, .name, (.resources.requests.cpu // "none"), (.resources.requests.memory // "none")] |
    @tsv' | column -t -s $'\t'
```

`clair-app` pods should show `100m` CPU requests, `quay-app` pods should show `500m`, and the
number of `clair-app` replicas should not exceed 2.

## Pros and Cons of the Options

### Resource overrides via `spec.components[].overrides`

* Good, because components remain fully managed by the operator
* Good, because overrides are expressed declaratively in the QuayRegistry CR — GitOps-friendly
* Good, because reduced Clair CPU request keeps the HPA from scaling aggressively — HPA scales on utilisation relative to the request, so a 100m request produces far more conservative scale-out than the 2-core default
* Bad, because operator upgrades may change default requests; overrides may need revisiting
* Bad, because `overrides.replicas` cannot be set when `horizontalpodautoscaler` is managed — replica count is indirectly controlled via the resource request instead

### Unmanage Clair

* Good, because eliminates Clair resource usage entirely
* Bad, because vulnerability scan data would be unavailable, breaking the planned Phase 6
  ACS pipeline security gate (see ADR-0012)

### Scale the cluster

* Good, because no changes to Quay configuration needed
* Bad, because adding worker nodes is not self-service on the Red Hat Demo Platform
* Bad, because it does not address the root cause — default requests are over-provisioned for
  demo workloads regardless of cluster size
