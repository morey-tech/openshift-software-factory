# GitLab

Self-hosted GitLab Community Edition — source control and collaboration platform for the software factory.

GitLab serves as the SCM for Developer Hub templates, catalog sources, and Dev Spaces git remotes. See [ADR-0014](../../docs/decisions/0014-gitlab-as-self-hosted-scm.md) for the decision rationale.

- `operator/` — Subscription and OperatorGroup for the GitLab Operator
- `instance/` — GitLab CR and initial root password Secret

## Prerequisites

- cert-manager must be installed and the `selfsigned-issuer` ClusterIssuer must exist before the GitLab instance syncs. See [`components/cert-manager`](../cert-manager/).

## Post-Deployment Setup

After GitLab is running:

1. Log in with `root` and the password from the `gitlab-initial-root-password` Secret.
2. Create a group named `software-factory`.
3. Create a personal access token (or group access token) with `read_api` and `read_repository` scopes.
4. Store the token in the `rhdh-gitlab-token` Secret in the `rhdh` namespace.
