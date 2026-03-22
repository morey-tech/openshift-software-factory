# cert-manager

Red Hat OpenShift cert-manager — TLS certificate lifecycle management.

- `operator/` — Subscription, OperatorGroup, and the `openshift-routes` Helm chart for Route TLS support
- `instance/` — ClusterIssuer configuration (disabled — see below)

## Demo Cluster Note

Both the operator and instance components are **disabled** (`"disabled": "true"` in their `config.json` files).

The Red Hat Demo Platform provisions clusters with cert-manager pre-installed and pre-configured. The demo cluster includes:

- A `CertManager` operand (`cluster`) managed by the OpenShift cert-manager operator
- Two `ClusterIssuers` using ACME DNS-01 via Route53:
  - `letsencrypt-production-aws` — primary issuer
  - `zerossl-production-aws-fallback` — fallback issuer
- Both issuers are authorised to issue certificates for:
  - `apps.cluster-<id>.dynamic.redhatworkshops.io`
  - `api.cluster-<id>.dynamic.redhatworkshops.io`

To discover what is available on your cluster:

```bash
oc get clusterissuer
oc get certmanager
oc get certificates -A
```

## Enabling on a Non-Demo Cluster

If deploying to a cluster without pre-installed cert-manager, set `"disabled": "false"` in both `operator/config.json` and `instance/config.json`, then add a `ClusterIssuer` manifest to `instance/manifests/` appropriate for your environment (self-signed, ACME, or Red Hat IdM).
