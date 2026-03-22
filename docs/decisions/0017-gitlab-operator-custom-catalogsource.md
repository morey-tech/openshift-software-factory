---
status: accepted
date: 2026-03-22
---

# Custom CatalogSource for GitLab Operator on OCP 4.21

## Context and Problem Statement

The GitLab Operator (`gitlab-operator-kubernetes`) officially supports OCP 4.21 as of version 2.9.0 per the [GitLab operator installation documentation](https://docs.gitlab.com/operator/installation/?tab=OpenShift). However, the latest bundle in `redhat-openshift-ecosystem/community-operators-prod` (version 2.9.2) declares:

```
com.redhat.openshift.versions: v4.12-v4.20
```

This annotation causes the OpenShift community-operator-index (`registry.redhat.io/redhat/community-operator-index:v4.21`) to exclude the operator, so it does not appear in the embedded OperatorHub on this OCP 4.21 cluster. The operator is also absent from `certified-operators` and `redhat-operators`. None of the four default catalog sources on the cluster include it.

## Decision Drivers

* The operator must be installable via OLM to fit the existing App-of-Apps pattern
* The workaround must not collide with existing or future cluster-wide catalog sources
* The workaround should be easy to remove once the upstream annotation is corrected

## Decision Outcome

Add a scoped `CatalogSource` named `gitlab-operator-catalog` in `openshift-marketplace` pointing to `quay.io/operatorhubio/catalog:latest` (the OperatorHub.io community catalog). The equivalent bundle in `k8s-operatorhub/community-operators` carries no `com.redhat.openshift.versions` annotation and is therefore visible on OCP 4.21.

The `Subscription` in `components/gitlab/operator/manifests/subscription.yaml` references `gitlab-operator-catalog` exclusively. The name avoids colliding with a generic `operatorhubio-catalog` source that may already exist or be added in the future.

### Consequences

* Good, because the operator is installable via OLM with no changes to the App-of-Apps pattern.
* Good, because the CatalogSource name is scoped (`gitlab-operator-catalog`) and does not affect any other operator subscriptions on the cluster.
* Bad, because the OperatorHub.io catalog image is large (~1 GB) and indexes all community operators, not just GitLab; initial sync takes several minutes.
* Bad, because OLM installation of the GitLab Operator is marked experimental by GitLab — they do not provide support for OLM-deployed instances.

### Confirmation

Workaround is functioning when:
```bash
oc get catalogsource gitlab-operator-catalog -n openshift-marketplace
oc get packagemanifest gitlab-operator-kubernetes -n openshift-marketplace
```
both return results.

## Removing This Workaround

This workaround can be removed when the `community-operators-prod` bundle annotation is updated to include `v4.21` (or uses an open-ended range). Track the upstream fix at:

> https://github.com/redhat-openshift-ecosystem/community-operators-prod/tree/main/operators/gitlab-operator-kubernetes

**Check:** Fetch the latest bundle's `annotations.yaml` and confirm `com.redhat.openshift.versions` includes `v4.21`:
```bash
curl -s https://api.github.com/repos/redhat-openshift-ecosystem/community-operators-prod/contents/operators/gitlab-operator-kubernetes \
  | python3 -c "import json,sys; versions=[x['name'] for x in json.load(sys.stdin) if x['type']=='dir']; print(sorted(versions)[-1])"
# Then check the latest version's metadata/annotations.yaml for the version range
```

**Steps to remove:**
1. Delete `components/gitlab/operator/manifests/catalog-source.yaml`
2. In `components/gitlab/operator/manifests/subscription.yaml`, change `source: gitlab-operator-catalog` to `source: community-operators`
3. Remove `catalog-source.yaml` from `components/gitlab/operator/manifests/kustomization.yaml`
4. Update the operator README
5. Mark this ADR as superseded
