#!/usr/bin/env bash
# Populates the rhdh-secrets Secret with all credentials RHDH needs at startup:
#   GITLAB_TOKEN   — GitLab root PAT (read_api, read/write_repository)
#   BACKEND_SECRET — random secret for the RHDH backend
#   APPS_DOMAIN    — cluster wildcard domain (e.g. apps.cluster.example.com)
#   ARGOCD_TOKEN   — API token for the ArgoCD local user 'rhdh'
#
# The ArgoCD token is read from the Secret that the ArgoCD operator auto-generates
# when localUsers[].autoRenewToken is true (Secret: argocd-rhdh-token in openshift-gitops).
#
# Follows the Job-generated secret pattern from ADR-0018.
set -euo pipefail

SECRET_NAME="rhdh-secrets"
SECRET_NAMESPACE="rhdh"
JOB_NAME="job-rhdh-secrets-init"
JOB_NAMESPACE="rhdh"
GITLAB_SECRET_NAME="gitlab-initial-root-password"
GITLAB_SECRET_NAMESPACE="gitlab-system"
ARGOCD_TOKEN_SECRET_NAME="rhdh-local-user"
ARGOCD_TOKEN_SECRET_NAMESPACE="openshift-gitops"

echo "Checking if ${SECRET_NAME} already exists..."
if oc get secret "${SECRET_NAME}" -n "${SECRET_NAMESPACE}" &>/dev/null; then
  # Check which required fields are present.
  # GITLAB_TOKEN and BACKEND_SECRET are generated (rotating them would break existing sessions)
  # so they are never overwritten. APPS_DOMAIN and ARGOCD_TOKEN are stable and safe to patch
  # in if missing.
  _field_value() {
    oc get secret "${SECRET_NAME}" -n "${SECRET_NAMESPACE}" \
      -o jsonpath="{.data.$1}" 2>/dev/null | base64 -d 2>/dev/null || true
  }

  HAS_TOKEN=$(_field_value GITLAB_TOKEN)
  HAS_SECRET=$(_field_value BACKEND_SECRET)
  HAS_DOMAIN=$(_field_value APPS_DOMAIN)
  HAS_ARGOCD=$(_field_value ARGOCD_TOKEN)

  if [[ -n "${HAS_TOKEN}" && -n "${HAS_SECRET}" && -n "${HAS_DOMAIN}" && -n "${HAS_ARGOCD}" ]]; then
    echo "Secret ${SECRET_NAME} already has all required fields, nothing to do."
    exit 0
  fi

  if [[ -n "${HAS_TOKEN}" && -n "${HAS_SECRET}" ]]; then
    # Generated fields are present; patch in any missing stable fields without
    # touching GITLAB_TOKEN or BACKEND_SECRET.
    PATCH_DATA="{}"
    if [[ -z "${HAS_DOMAIN}" ]]; then
      echo "Patching missing APPS_DOMAIN..."
      APPS_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
      PATCH_DATA=$(echo "${PATCH_DATA}" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); d.setdefault('stringData',{})['APPS_DOMAIN']='${APPS_DOMAIN}'; print(json.dumps(d))")
    fi
    if [[ -z "${HAS_ARGOCD}" ]]; then
      echo "Patching missing ARGOCD_TOKEN..."
      ARGOCD_TOKEN=$(oc get secret "${ARGOCD_TOKEN_SECRET_NAME}" \
        -n "${ARGOCD_TOKEN_SECRET_NAMESPACE}" \
        -o jsonpath='{.data.token}' | base64 -d)
      if [[ -z "${ARGOCD_TOKEN}" ]]; then
        echo "ERROR: ArgoCD token Secret '${ARGOCD_TOKEN_SECRET_NAME}' not found or empty"
        exit 1
      fi
      PATCH_DATA=$(echo "${PATCH_DATA}" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); d.setdefault('stringData',{})['ARGOCD_TOKEN']='${ARGOCD_TOKEN}'; print(json.dumps(d))")
    fi
    oc patch secret "${SECRET_NAME}" -n "${SECRET_NAMESPACE}" \
      --type=merge \
      --patch "${PATCH_DATA}"
    echo "Patched ${SECRET_NAME} with missing fields."
    exit 0
  fi

  # Generated fields are missing — delete so the full creation flow runs.
  echo "Secret ${SECRET_NAME} is missing generated fields, deleting for recreation..."
  oc delete secret "${SECRET_NAME}" -n "${SECRET_NAMESPACE}"
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

echo "Reading ArgoCD local-user token for 'rhdh'..."
ARGOCD_TOKEN=$(oc get secret "${ARGOCD_TOKEN_SECRET_NAME}" \
  -n "${ARGOCD_TOKEN_SECRET_NAMESPACE}" \
  -o jsonpath='{.data.apiToken}' | base64 -d)
if [[ -z "${ARGOCD_TOKEN}" ]]; then
  echo "ERROR: ArgoCD token Secret '${ARGOCD_TOKEN_SECRET_NAME}' not found or empty in ${ARGOCD_TOKEN_SECRET_NAMESPACE}"
  exit 1
fi
echo "ArgoCD token retrieved successfully."

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
  APPS_DOMAIN: "${APPS_DOMAIN}"
  ARGOCD_TOKEN: "${ARGOCD_TOKEN}"
EOF

echo "Done. The rhdh-secrets Secret has been created in the ${SECRET_NAMESPACE} namespace."
