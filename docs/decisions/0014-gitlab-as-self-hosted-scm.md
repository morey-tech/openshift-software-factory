---
status: accepted
date: 2026-03-22
---

# Use GitLab Operator as the Self-Hosted SCM

## Context and Problem Statement

The software factory needs a Git hosting platform to serve as the SCM for Developer Hub templates, catalog sources, and Dev Spaces git remotes. The factory must be fully self-contained on the OpenShift cluster — no dependency on external services like GitHub or GitLab.com. Which Git hosting solution should be deployed?

## Decision Drivers

* Must run fully on-cluster; no external SCM dependency
* Should be deployed via an OLM operator to fit the existing App-of-Apps pattern
* Must integrate with Red Hat Developer Hub (Backstage) for catalog discovery and software templates
* Should support group/organization structure for organizing platform and application repositories
* Phase 5 golden path templates will need webhooks, access tokens, and possibly a package registry

## Considered Options

* GitLab CE (Community Edition) via the GitLab Operator
* Gitea via Helm chart
* Forgejo via Helm chart

## Decision Outcome

Chosen option: **GitLab CE via the GitLab Operator**, because it is the only option that fits the OLM operator pattern already established for every other component in this repository. The GitLab Operator is Red Hat OpenShift certified and available through the certified-operators catalog.

### Consequences

* Good, because deployment and lifecycle management follow the same operator pattern as all other components — no special-casing needed in the ApplicationSets.
* Good, because GitLab's group model maps cleanly to RHDH catalog discovery (one `software-factory` group, discovered via `gitlabDiscovery` provider).
* Good, because GitLab CE includes webhooks, access tokens, a package registry, and CI/CD — all of which will be needed in Phase 5.
* Bad, because GitLab is significantly more resource-intensive than Gitea or Forgejo.
* Bad, because the GitLab Operator requires cert-manager as a prerequisite, which adds a component to this phase.
* Bad, because GitLab's domain configuration is static in the CR; it must be updated to match the cluster's base domain before first deployment.

### Confirmation

Deployment is confirmed when `oc get gitlab gitlab -n gitlab-system -o jsonpath='{.status.phase}'` returns `Running` and the GitLab web UI is reachable via the cluster Route.

## Pros and Cons of the Options

### GitLab CE via the GitLab Operator

* Good, because OLM operator — fits the existing pattern exactly
* Good, because Red Hat OpenShift certified
* Good, because rich feature set (groups, webhooks, package registry, CI/CD) needed for Phase 5
* Good, because RHDH has a first-class GitLab integration (`gitlabDiscovery`, `gitlabOrg` providers)
* Neutral, because Community Edition is free (MIT licensed)
* Bad, because requires cert-manager prerequisite
* Bad, because resource-heavy (Postgres, Redis, Gitaly, MinIO all deployed)

### Gitea via Helm chart

* Good, because extremely lightweight and fast to start
* Good, because RHDH has community-supported Gitea integration plugins
* Bad, because no OLM operator — would require a standalone Argo CD Application with a Helm source, deviating from the git-files-generator pattern
* Bad, because fewer built-in features for Phase 5 use cases

### Forgejo via Helm chart

* Good, because Gitea fork with active community
* Bad, because same structural problem as Gitea — no OLM operator
* Bad, because even less RHDH integration support than Gitea
