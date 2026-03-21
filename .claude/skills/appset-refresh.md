# ApplicationSet Refresh Skill

Trigger an immediate refresh of the `operators` and `operands` ApplicationSets after changes to component manifests.

## When to apply

After adding or modifying files under `components/*/operator/` or `components/*/instance/` — especially new `config.json` files or manifest changes that should be picked up by the ApplicationSet git files generator without waiting for the next polling interval.

## Steps

Run both annotations in a single message (parallel tool calls):

```
oc annotate applicationset operators -n openshift-gitops argocd.argoproj.io/application-set-refresh=true --overwrite
oc annotate applicationset operands -n openshift-gitops argocd.argoproj.io/application-set-refresh=true --overwrite
```

The ApplicationSet controller removes the annotation after reconciliation. The `--overwrite` flag is required in case the annotation is still present from a previous refresh that hasn't completed yet.

## Expected output

```
applicationset.argoproj.io/operators annotated
applicationset.argoproj.io/operands annotated
```

If the command fails with "not found", the cluster is not reachable or the ApplicationSet does not exist yet — confirm `oc` is logged in and the bootstrap playbook has been run.
