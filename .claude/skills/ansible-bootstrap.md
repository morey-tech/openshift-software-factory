# Ansible Bootstrap Skill

Keep `ansible/bootstrap.yaml` in sync when files it references are moved, renamed, or added.

## When to apply

After any change to files directly referenced by `ansible/bootstrap.yaml` — specifically manifests in:
- `components/openshift-gitops/operator/manifests/`
- `components/openshift-gitops/instance/manifests/`

If any of those files are moved or renamed, the `src:` paths in the playbook must be updated to match.

## What to update

The playbook uses hardcoded `src:` paths for the files it applies before ArgoCD is available, plus an inline `definition:` for the standalone Application:

| Task | Reference |
|------|-----------|
| Apply OperatorGroup | `src: components/openshift-gitops/operator/manifests/operator-group.yaml` |
| Apply GitOps operator Subscription | `src: components/openshift-gitops/operator/manifests/subscription.yaml` |
| Apply ClusterRole for Argo CD | `src: components/openshift-gitops/instance/manifests/cluster-role.yaml` |
| Apply cluster-admins group | `src: components/openshift-gitops/instance/manifests/cluster-admins-group.yaml` |
| Apply ClusterRoleBinding for cluster-admins group | `src: components/openshift-gitops/instance/manifests/cluster-role-binding.yaml` |
| Apply ArgoCD instance | `src: components/openshift-gitops/instance/manifests/argocd.yaml` |
| Apply standalone openshift-gitops-instance Application | inline `definition:` pointing to `components/openshift-gitops/instance/manifests` |

Update the matching `src:` line or inline path in `ansible/bootstrap.yaml` to reflect the new path.

## Why this matters

ArgoCD manages most components via GitOps, but the GitOps operator and ArgoCD instance must exist before ArgoCD is available. The bootstrap playbook applies these resources directly. It is not auto-discovered — paths are hardcoded and will break silently if files move.

The standalone `openshift-gitops-instance` Application is also applied directly by the playbook (not via the operands AppSet) to prevent a cascade deadlock during teardown. See `docs/decisions/0011-decouple-gitops-instance-from-bootstrap-cascade.md`.
