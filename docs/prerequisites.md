# Prerequisites

This document describes the assumptions and requirements for the target OpenShift cluster before running the bootstrap playbook.

## Cluster

- OpenShift Container Platform cluster, accessible via `oc` or `kubectl`
- `KUBECONFIG` environment variable set, or a valid `~/.kube/config` pointing at the cluster
- The `oc` CLI and `ansible-playbook` available on the machine running the bootstrap

## User Accounts

### `admin` user (required)

The bootstrap assumes an `admin` user exists on the cluster. This user is added to the `cluster-admins` OpenShift Group (see [cluster-admins-group.yaml](../components/openshift-gitops/instance/manifests/cluster-admins-group.yaml)), which grants access to the Argo CD instance via its RBAC policy (see [ADR-0006](decisions/0006-cluster-admins-group-for-argocd-rbac.md)).

The Red Hat Demo Platform provisions clusters with an `admin` user by default. If your cluster uses a different administrative username, update the `users` list in [cluster-admins-group.yaml](../components/openshift-gitops/instance/manifests/cluster-admins-group.yaml) before bootstrapping.

## Storage

A default `StorageClass` must be configured on the cluster. Several components (Quay, Developer Hub, Dev Spaces) provision `PersistentVolumeClaims` without specifying a storage class, relying on the cluster default to satisfy them.

On the Red Hat Demo Platform this is provisioned automatically. On other clusters, verify with:

```bash
oc get storageclass
```

The default storage class is marked with the annotation `storageclass.kubernetes.io/is-default-class: "true"`.

## Object Storage (Quay)

Quay requires object storage and provisions an `ObjectBucketClaim` to request a bucket. This requires the `ObjectBucketClaim` CRD to be available on the cluster, which is provided by [NooBaa](https://www.noobaa.io/) — typically deployed as part of [OpenShift Data Foundation (ODF)](https://www.redhat.com/en/technologies/cloud-computing/openshift-data-foundation).

On the Red Hat Demo Platform, ODF (including NooBaa) is included by default. On other clusters, install ODF or deploy NooBaa standalone before bootstrapping.

Verify NooBaa and the `ObjectBucketClaim` CRD are available with:

```bash
oc get noobaa -n openshift-storage
oc get crd objectbucketclaims.objectbucket.io
```

## Ansible

The following Python packages are required on the control machine:

```bash
pip install ansible kubernetes
ansible-galaxy collection install kubernetes.core
```
