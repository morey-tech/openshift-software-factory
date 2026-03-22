#!/usr/bin/env bash
set -euo pipefail

SECRET_NAME="gitlab-initial-root-password"
NAMESPACE="gitlab-system"
JOB_NAME="job-gitlab-root-password"

echo "Checking if ${SECRET_NAME} already exists..."
if oc get secret "${SECRET_NAME}" -n "${NAMESPACE}" &>/dev/null; then
  echo "Secret ${SECRET_NAME} already exists, nothing to do."
  exit 0
fi

echo "Generating random password..."
# GitLab requires minimum 8 characters; 32-char base64 satisfies all requirements.
PASSWORD=$(openssl rand -base64 32 | tr -d '\n/+=' | cut -c1-32)

echo "Fetching Job UID for ownerReference..."
JOB_UID=$(oc get job "${JOB_NAME}" -n "${NAMESPACE}" -o jsonpath='{.metadata.uid}')

echo "Creating Secret ${SECRET_NAME}..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
  ownerReferences:
    - apiVersion: batch/v1
      blockOwnerDeletion: false
      controller: true
      kind: Job
      name: ${JOB_NAME}
      uid: ${JOB_UID}
type: Opaque
stringData:
  password: "${PASSWORD}"
EOF

echo "Done. Retrieve the password with:"
echo "  oc get secret ${SECRET_NAME} -n ${NAMESPACE} -o jsonpath='{.data.password}' | base64 -d"
