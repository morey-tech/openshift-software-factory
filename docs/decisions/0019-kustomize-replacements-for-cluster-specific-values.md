---
status: accepted
date: 2026-03-22
---

# Kustomize Replacements for Cluster-Specific Values

## Context and Problem Statement

Some component manifests require values that are specific to the target cluster and cannot be known ahead of time — for example, the cluster's apps subdomain (`apps.<cluster-id>.<base-domain>`). Hardcoding these values directly in component manifests couples the repository to a single cluster and creates scattered, easy-to-miss manual edits before each deployment.

The first instance of this problem is the `spec.chart.values.global.hosts.domain` field in the GitLab CR, which must be set to the cluster's apps domain for OpenShift Routes to resolve correctly.

## Decision Drivers

* Cluster-specific values should be isolated to one place per component so a re-deployment to a different cluster requires minimal, obvious changes
* The approach must work within the existing ApplicationSet + Kustomize pattern without adding new tools
* Values should be substituted at build time (when Argo CD renders manifests), not at runtime via a Job

## Considered Options

* **Edit the CR directly** — replace placeholder strings inline before committing
* **Kustomize `replacements`** — store cluster-specific values in a `cluster-config.yaml` ConfigMap; Kustomize substitutes them into component manifests at build time
* **Domain-discovery Job** — a Job reads cluster metadata at deploy time and patches the CR
* **Standalone Route with no `spec.host`** — omit the domain from the GitLab CR entirely and create a bare Route; OpenShift auto-assigns a hostname

## Decision Outcome

Chosen option: **Kustomize `replacements`**, because it keeps cluster-specific values isolated to a single `cluster-config.yaml` file per component while remaining entirely within the existing Kustomize + Argo CD toolchain.

### How it works

A `cluster-config.yaml` ConfigMap is added to the component's `manifests/` directory alongside the other resources:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-config
  namespace: <component-namespace>
data:
  appsDomain: apps.cluster-7v46r.dynamic.redhatworkshops.io
```

The `kustomization.yaml` declares a replacement that reads `data.appsDomain` from the ConfigMap and writes it into the target resource field:

```yaml
replacements:
  - source:
      kind: ConfigMap
      name: cluster-config
      fieldPath: data.appsDomain
    targets:
      - select:
          kind: GitLab
          name: gitlab
        fieldPaths:
          - spec.chart.values.global.hosts.domain
```

The ConfigMap is also listed under `resources:` so it is deployed to the cluster alongside the component, serving as visible, queryable documentation of the cluster-specific configuration that was applied.

### Consequences

* Good, because all cluster-specific values for a component are in one file (`cluster-config.yaml`), making cross-cluster re-deployment straightforward.
* Good, because substitution happens at Kustomize build time — Argo CD renders the correct final manifest with no runtime patching required.
* Good, because the ConfigMap is deployed to the cluster, so `kubectl get configmap cluster-config` shows the active configuration.
* Bad, because `cluster-config.yaml` must be updated before the component is synced to a new cluster; the build will silently use the placeholder string if this is forgotten. A pre-sync validation hook could catch this in future.
* Bad, because Kustomize `replacements` require the target field to already exist in the source manifest; a missing field will cause the build to fail with an unhelpful error.

### Confirmation

Verify that the replacement applied correctly after a `kustomize build`:

```bash
kubectl kustomize components/<component>/instance/manifests/ | grep "domain:"
# Expected: domain: apps.<actual-cluster-domain>
```

## Rejected Option: Standalone Route with No `spec.host`

OpenShift Routes created without `spec.host` receive an auto-generated hostname following the pattern `<route-name>-<namespace>.<apps-domain>`. At first glance this appears to eliminate the need to know the apps domain ahead of time.

However, GitLab must be told its own external URL at deploy time — it uses this value to generate web URLs, repository clone URLs, and OAuth redirects. This is configured via `global.hosts.domain` (or `global.hosts.gitlab.name`). Whether the domain comes from an Ingress, a Route, or a manually created resource, the apps domain is unavoidable: it must appear somewhere in the GitLab CR values.

The only way to make this fully dynamic would be the domain-discovery Job approach: create the Route first with no host, wait for OpenShift to assign a hostname, read it back, then patch the GitLab CR. This introduces ordering dependencies, race conditions, and operational complexity for a value that is stable for the entire lifetime of a cluster — making it a poor trade-off.

## Adapting to a New Cluster

1. Run `oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'` on the target cluster.
2. Update `data.appsDomain` in the component's `cluster-config.yaml` with the result.
3. Commit and push — Argo CD will render and sync the updated manifest.
