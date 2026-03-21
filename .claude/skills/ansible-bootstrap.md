# Ansible Bootstrap Skill

Keep `ansible/bootstrap.yaml` in sync when files it references are moved, renamed, or added.

## When to apply

After any change to files directly referenced by `ansible/bootstrap.yaml` — specifically manifests in:
- `components/openshift-gitops/operator/manifests/`
- `components/openshift-gitops/instance/manifests/`

If any of those files are moved or renamed, the `src:` paths in the playbook must be updated to match.

## What to update

The playbook uses hardcoded `src:` paths for the files it applies before ArgoCD is available:

| Task | File |
|------|------|
| Apply OperatorGroup | `components/openshift-gitops/operator/manifests/operator-group.yaml` |
| Apply GitOps operator Subscription | `components/openshift-gitops/operator/manifests/subscription.yaml` |
| Apply ClusterRole for Argo CD | `components/openshift-gitops/instance/manifests/cluster-role.yaml` |
| Apply cluster-admins group | `components/openshift-gitops/instance/manifests/cluster-admins-group.yaml` |
| Apply ClusterRoleBinding for cluster-admins group | `components/openshift-gitops/instance/manifests/cluster-role-binding.yaml` |
| Apply ArgoCD instance | `components/openshift-gitops/instance/manifests/argocd.yaml` |

Update the matching `src:` line in `ansible/bootstrap.yaml` to reflect the new path.

## Why this matters

ArgoCD manages most components via GitOps, but the GitOps operator and ArgoCD instance itself must exist before ArgoCD is available. The bootstrap playbook applies these resources directly via `kubernetes.core.k8s`. It is not auto-discovered — paths are hardcoded and will break silently if files move.
