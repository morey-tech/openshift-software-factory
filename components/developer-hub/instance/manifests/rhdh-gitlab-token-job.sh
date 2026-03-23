#!/usr/bin/env bash
# Generates a GitLab personal access token for the root user and stores it
# (along with a random BACKEND_SECRET) in the rhdh-secrets Secret in the
# rhdh namespace.
#
# Follows the Job-generated secret pattern from ADR-0018.
set -euo pipefail

SECRET_NAME="rhdh-secrets"
SECRET_NAMESPACE="rhdh"
JOB_NAME="job-rhdh-gitlab-token"
JOB_NAMESPACE="rhdh"
GITLAB_SECRET_NAME="gitlab-initial-root-password"
GITLAB_SECRET_NAMESPACE="gitlab-system"

echo "Checking if ${SECRET_NAME} already exists..."
if oc get secret "${SECRET_NAME}" -n "${SECRET_NAMESPACE}" &>/dev/null; then
  echo "Secret ${SECRET_NAME} already exists, nothing to do."
  exit 0
fi

echo "Discovering apps domain from cluster ingress config..."
APPS_DOMAIN=$(oc get ingresses.config.openshift.io cluster \
  -o jsonpath='{.spec.domain}')
GITLAB_URL="https://gitlab.${APPS_DOMAIN}"
echo "GitLab URL: ${GITLAB_URL}"

echo "Reading GitLab root password..."
ROOT_PASSWORD=$(oc get secret "${GITLAB_SECRET_NAME}" -n "${GITLAB_SECRET_NAMESPACE}" \
  -o jsonpath='{.data.password}' | base64 -d)

echo "Waiting for GitLab to become healthy..."
MAX_ATTEMPTS=120
ATTEMPT=0
until curl -skf --max-time 5 "${GITLAB_URL}/-/health" &>/dev/null; do
  ATTEMPT=$((ATTEMPT + 1))
  HTTP_STATUS=$(curl -sk --max-time 5 -o /dev/null -w "%{http_code}" "${GITLAB_URL}/-/health" 2>&1 || true)
  CURL_EXIT=$?
  echo "  GitLab not ready yet (attempt ${ATTEMPT}/${MAX_ATTEMPTS}): HTTP=${HTTP_STATUS} curl_exit=${CURL_EXIT}"
  if [[ ${ATTEMPT} -ge ${MAX_ATTEMPTS} ]]; then
    echo "ERROR: GitLab did not become healthy after $((MAX_ATTEMPTS * 5))s"
    exit 1
  fi
  sleep 5
done
echo "GitLab is healthy."

echo "Obtaining OAuth token for root user..."
OAUTH_RESPONSE=$(curl -skf --max-time 15 \
  --data "grant_type=password&username=root&password=${ROOT_PASSWORD}" \
  "${GITLAB_URL}/oauth/token")
OAUTH_TOKEN=$(echo "${OAUTH_RESPONSE}" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
if [[ -z "${OAUTH_TOKEN}" ]]; then
  echo "ERROR: Failed to obtain OAuth token from GitLab"
  exit 1
fi

echo "Creating GitLab personal access token for root user..."
TOKEN_RESPONSE=$(curl -skf --max-time 15 \
  -X POST "${GITLAB_URL}/api/v4/users/1/personal_access_tokens" \
  -H "Authorization: Bearer ${OAUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"name":"rhdh-token","scopes":["read_api","read_repository","write_repository"]}')
GITLAB_TOKEN=$(echo "${TOKEN_RESPONSE}" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
if [[ -z "${GITLAB_TOKEN}" ]]; then
  echo "ERROR: Failed to create personal access token"
  exit 1
fi
echo "GitLab token created successfully."

echo "Generating BACKEND_SECRET..."
BACKEND_SECRET=$(openssl rand -base64 32 | tr -d '\n')

echo "Fetching Job UID for ownerReference..."
JOB_UID=$(oc get job "${JOB_NAME}" -n "${JOB_NAMESPACE}" -o jsonpath='{.metadata.uid}')

echo "Creating Secret ${SECRET_NAME} in ${SECRET_NAMESPACE}..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${SECRET_NAMESPACE}
  ownerReferences:
    - apiVersion: batch/v1
      blockOwnerDeletion: false
      controller: true
      kind: Job
      name: ${JOB_NAME}
      uid: ${JOB_UID}
type: Opaque
stringData:
  GITLAB_TOKEN: "${GITLAB_TOKEN}"
  BACKEND_SECRET: "${BACKEND_SECRET}"
EOF

echo "Done. The rhdh-secrets Secret has been created in the ${SECRET_NAMESPACE} namespace."
