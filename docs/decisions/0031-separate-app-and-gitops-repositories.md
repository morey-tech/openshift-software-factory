---
status: accepted
date: 2026-03-25
---

# Separate Application Source and GitOps Repositories per Scaffolded App

## Context and Problem Statement

The golden path template scaffolds a complete application — source code, build pipeline, and
Kubernetes deployment manifests. These artefacts have different audiences, change rates, and
access control requirements. Should they live in a single repository or in separate repositories?

## Decision Drivers

* ArgoCD watches a repository for Kubernetes manifest changes and syncs them to the cluster;
  mixing application source commits into that stream triggers unnecessary sync evaluations and
  pollutes the GitOps audit trail
* Tekton pipelines run on every source commit; including deployment manifests in the source repo
  means every manifest-only change triggers a full build — wasting pipeline capacity
* Access control requirements differ: developers need write access to source code; only the
  pipeline (and platform engineers) should be able to promote new image tags into the GitOps
  repo
* The ArgoCD project documentation explicitly recommends this separation:
  https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/#separating-config-vs-source-code-repositories

## Considered Options

* **Two repositories per app** — `{name}` for application source, `{name}-gitops` for
  Kubernetes manifests
* **Single repository per app** — source and manifests co-located, ArgoCD pointed at a
  `gitops/` subdirectory
* **Shared platform GitOps repository** — all apps' manifests in one central repo managed by
  the platform team

## Decision Outcome

Chosen option: **Two repositories per app**, because it cleanly separates build triggers from
deployment triggers, enables independent access control, and aligns with ArgoCD's own best
practice guidance.

The Backstage scaffolder template implements this as a 6-step workflow:

1. Render `skeleton/` → publish to `software-factory/apps/{name}`
2. Render `gitops-skeleton/` → publish to `software-factory/apps/{name}-gitops`
3. Create an ArgoCD Application pointing at `{name}-gitops/overlays/dev`

The Tekton PipelineRun (embedded in the source skeleton) receives both repo URLs as parameters
so the pipeline can open a merge request against the GitOps repo to promote a newly built image
tag without the pipeline having write access to the source repo.

### Consequences

* Good, because ArgoCD only reacts to manifest changes — source commits do not trigger
  spurious sync cycles
* Good, because Tekton pipelines only trigger on source commits — manifest-only changes (e.g.,
  replica count adjustments) do not kick off a full build
* Good, because GitLab access control can be scoped independently: developer write access on
  `{name}`, pipeline service account write access on `{name}-gitops`
* Good, because the GitOps repo provides a clean, auditable history of every deployment
  promotion — uncluttered by source history
* Bad, because scaffolding two repos per app adds complexity to the template (two `publish:gitlab`
  steps, `targetPath` isolation in the workspace)
* Bad, because developers must navigate between two repositories; cross-referencing a source
  change with its corresponding deployment promotion requires correlating commits across repos

### Confirmation

After scaffolding an application from the Quarkus Web Application template, confirm:

```bash
# Both repos exist under the apps subgroup
curl --header "PRIVATE-TOKEN: <token>" \
  https://<gitlab-host>/api/v4/groups/software-factory%2Fapps/projects | \
  jq '.[].name' | grep -E '"<appname>"|"<appname>-gitops"'

# ArgoCD Application points at the gitops repo, not the source repo
argocd app get <appname>-dev -o json | jq '.spec.source.repoURL'
```

## Pros and Cons of the Options

### Two repositories per app

* Good, because build and deploy triggers are fully decoupled
* Good, because access control can be scoped per repo
* Good, because deployment history is clean and auditable independently of source history
* Good, because aligns with ArgoCD best practices
* Bad, because template implementation is more complex (two publish steps, workspace path
  isolation)
* Bad, because developers work across two repos

### Single repository per app

* Good, because simpler for developers — one place for everything
* Good, because simpler template — one publish step
* Bad, because every source commit triggers ArgoCD sync evaluation, even if no manifests changed
* Bad, because every manifest change triggers a Tekton pipeline build
* Bad, because a single compromised developer credential grants write access to both source
  and deployment manifests

### Shared platform GitOps repository

* Good, because platform team has full visibility and control over all deployments
* Good, because a single repo for all ArgoCD Applications simplifies RBAC configuration
* Bad, because it becomes a bottleneck — all teams' deployment changes serialise through one
  repo and one team's review process
* Bad, because merge conflicts are likely when multiple teams promote images simultaneously
* Bad, because it breaks the self-service model — developers cannot update their own manifests
  without a platform team PR
