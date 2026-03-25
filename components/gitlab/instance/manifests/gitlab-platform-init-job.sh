#!/usr/bin/env bash
# Creates the GitLab group hierarchy and seeds the software-factory-catalog repo
# for RHDH golden path template discovery.
#
# Groups created:
#   software-factory/           (top-level)
#   software-factory/platform   (platform repos, including the catalog)
#   software-factory/apps       (repos scaffolded by the golden path template)
#
# Repos created:
#   software-factory/platform/software-factory-catalog
#     ├── catalog-info.yaml     (Backstage Location pointing to ./template.yaml)
#     └── template.yaml         (Quarkus golden path Template entity)
set -euo pipefail

GITLAB_SECRET_NAME="gitlab-initial-root-password"
GITLAB_SECRET_NAMESPACE="gitlab-system"

echo "Discovering apps domain from cluster ingress config..."
APPS_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}')
GITLAB_URL="https://gitlab.${APPS_DOMAIN}"
echo "GitLab URL: ${GITLAB_URL}"

echo "Reading GitLab root password..."
ROOT_PASSWORD=$(oc get secret "${GITLAB_SECRET_NAME}" -n "${GITLAB_SECRET_NAMESPACE}" \
  -o jsonpath='{.data.password}' | base64 -d)

echo "Waiting for GitLab to become healthy..."
# GitLab can take 30-60 minutes on initial deployment (Postgres migration,
# asset compilation, etc.). 360 attempts × 10s = 60 minutes maximum wait.
MAX_ATTEMPTS=360
ATTEMPT=0
until curl -skf --max-time 10 "${GITLAB_URL}/-/health" &>/dev/null; do
  ATTEMPT=$((ATTEMPT + 1))
  HTTP_STATUS=$(curl -sk --max-time 10 -o /dev/null -w "%{http_code}" "${GITLAB_URL}/-/health" 2>&1 || true)
  CURL_EXIT=$?
  echo "  GitLab not ready yet (attempt ${ATTEMPT}/${MAX_ATTEMPTS}): HTTP=${HTTP_STATUS} curl_exit=${CURL_EXIT}"
  if [[ ${ATTEMPT} -ge ${MAX_ATTEMPTS} ]]; then
    echo "ERROR: GitLab did not become healthy after $((MAX_ATTEMPTS * 10))s"
    exit 1
  fi
  sleep 10
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

# Idempotency: if the top-level group already exists, nothing to do.
echo "Checking if software-factory group already exists..."
SF_STATUS=$(curl -sk --max-time 10 \
  -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${OAUTH_TOKEN}" \
  "${GITLAB_URL}/api/v4/groups/software-factory")
if [[ "${SF_STATUS}" == "200" ]]; then
  echo "software-factory group already exists, nothing to do."
  exit 0
fi

# --- Create top-level group ---
echo "Creating software-factory group..."
SF_RESPONSE=$(curl -skf --max-time 15 \
  -X POST "${GITLAB_URL}/api/v4/groups" \
  -H "Authorization: Bearer ${OAUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"name":"Software Factory","path":"software-factory","visibility":"private"}')
SF_ID=$(echo "${SF_RESPONSE}" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
if [[ -z "${SF_ID}" ]]; then
  echo "ERROR: Failed to create software-factory group. Response: ${SF_RESPONSE}"
  exit 1
fi
echo "Created software-factory group (id=${SF_ID})."

# --- Create platform subgroup ---
echo "Creating platform subgroup..."
PLATFORM_RESPONSE=$(curl -skf --max-time 15 \
  -X POST "${GITLAB_URL}/api/v4/groups" \
  -H "Authorization: Bearer ${OAUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Platform\",\"path\":\"platform\",\"parent_id\":${SF_ID},\"visibility\":\"private\"}")
PLATFORM_ID=$(echo "${PLATFORM_RESPONSE}" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
if [[ -z "${PLATFORM_ID}" ]]; then
  echo "ERROR: Failed to create platform subgroup. Response: ${PLATFORM_RESPONSE}"
  exit 1
fi
echo "Created platform subgroup (id=${PLATFORM_ID})."

# --- Create apps subgroup ---
echo "Creating apps subgroup..."
APPS_RESPONSE=$(curl -skf --max-time 15 \
  -X POST "${GITLAB_URL}/api/v4/groups" \
  -H "Authorization: Bearer ${OAUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Apps\",\"path\":\"apps\",\"parent_id\":${SF_ID},\"visibility\":\"private\"}")
APPS_ID=$(echo "${APPS_RESPONSE}" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
if [[ -z "${APPS_ID}" ]]; then
  echo "ERROR: Failed to create apps subgroup. Response: ${APPS_RESPONSE}"
  exit 1
fi
echo "Created apps subgroup (id=${APPS_ID})."

# --- Create software-factory-catalog project ---
echo "Creating software-factory-catalog project under platform..."
CATALOG_RESPONSE=$(curl -skf --max-time 15 \
  -X POST "${GITLAB_URL}/api/v4/projects" \
  -H "Authorization: Bearer ${OAUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"software-factory-catalog\",\"path\":\"software-factory-catalog\",\"namespace_id\":${PLATFORM_ID},\"visibility\":\"private\"}")
CATALOG_ID=$(echo "${CATALOG_RESPONSE}" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
if [[ -z "${CATALOG_ID}" ]]; then
  echo "ERROR: Failed to create software-factory-catalog project. Response: ${CATALOG_RESPONSE}"
  exit 1
fi
echo "Created software-factory-catalog project (id=${CATALOG_ID})."

# --- Seed catalog repository via git ---
# Clones the platform repo (single source of truth for template files) and
# pushes catalog/templates/quarkus-web-template/ as the catalog repo root.
# This avoids duplicating any file content in this script.
echo "Seeding catalog repository via git..."
SOURCE_DIR=$(mktemp -d)
WORK_DIR=$(mktemp -d)
GITLAB_HOST="${GITLAB_URL#https://}"

echo "Cloning platform repo to get authoritative template files..."
git clone --depth=1 https://github.com/morey-tech/openshift-software-factory.git "${SOURCE_DIR}"

cd "${WORK_DIR}"
git init -b main
git config user.email "platform-init@software-factory.local"
git config user.name "Platform Init Job"
git remote add origin \
  "https://oauth2:${OAUTH_TOKEN}@${GITLAB_HOST}/software-factory/platform/software-factory-catalog.git"

# Copy the full template directory (catalog-info.yaml, template.yaml,
# skeleton/, gitops-skeleton/) as the catalog repo root.
cp -r "${SOURCE_DIR}/catalog/templates/quarkus-web-template/." .

git add -A
git commit -m "Initial platform catalog seed"
git push -u origin main

cd /
rm -rf "${SOURCE_DIR}" "${WORK_DIR}"

echo "Done. GitLab group structure initialized:"
echo "  software-factory/ (id=${SF_ID})"
echo "    platform/       (id=${PLATFORM_ID})"
echo "      software-factory-catalog (id=${CATALOG_ID})"
echo "    apps/           (id=${APPS_ID})"
