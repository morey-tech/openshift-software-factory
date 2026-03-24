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
  -d "{\"name\":\"software-factory-catalog\",\"path\":\"software-factory-catalog\",\"namespace_id\":${PLATFORM_ID},\"initialize_with_readme\":true,\"visibility\":\"private\"}")
CATALOG_ID=$(echo "${CATALOG_RESPONSE}" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
if [[ -z "${CATALOG_ID}" ]]; then
  echo "ERROR: Failed to create software-factory-catalog project. Response: ${CATALOG_RESPONSE}"
  exit 1
fi
echo "Created software-factory-catalog project (id=${CATALOG_ID})."

# --- Seed catalog-info.yaml ---
# Backstage Location entity — entry point that RHDH's gitlabOrg provider
# discovers automatically. The relative ./template.yaml reference resolves to
# the template.yaml seeded in the same commit below.
echo "Seeding catalog-info.yaml in software-factory-catalog..."
CATALOG_CONTENT=$(cat <<'EOF'
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: quarkus-web-template
  description: Golden path template for Quarkus web applications
spec:
  targets:
    - ./template.yaml
EOF
)
# Base64-encode for the GitLab files API (avoids newline/quoting issues
# when embedding YAML inside a JSON payload).
CATALOG_CONTENT_B64=$(printf '%s' "${CATALOG_CONTENT}" | base64 | tr -d '\n')

curl -skf --max-time 15 \
  -X POST "${GITLAB_URL}/api/v4/projects/${CATALOG_ID}/repository/files/catalog-info.yaml" \
  -H "Authorization: Bearer ${OAUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"branch\":\"main\",\"encoding\":\"base64\",\"content\":\"${CATALOG_CONTENT_B64}\",\"commit_message\":\"Initial catalog-info.yaml\"}" \
  > /dev/null

# --- Seed template.yaml ---
# The Backstage Template entity for the Quarkus golden path. Seeded here so
# the catalog is fully self-contained on-cluster with no GitHub dependency.
# Single-quoted heredoc preserves ${{...}} template syntax verbatim.
echo "Seeding template.yaml in software-factory-catalog..."
TEMPLATE_CONTENT=$(cat <<'EOF'
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: quarkus-web-template
  title: Quarkus Web Application
  description: >-
    Scaffold a Quarkus reactive web application with a Tekton build pipeline,
    ArgoCD GitOps deployment, and a Dev Spaces workspace.
  tags:
    - quarkus
    - java
    - recommended
spec:
  owner: group:platform-engineering
  type: service

  parameters:
    - title: Application Details
      required: [name, description, owner, system]
      properties:
        name:
          title: Name
          type: string
          description: >-
            Unique name for your app — becomes the GitLab repo name and
            Kubernetes resource name (lowercase, hyphens only)
          ui:autofocus: true
          ui:field: EntityNamePicker
        description:
          title: Description
          type: string
          description: Short description of the application
        owner:
          title: Owner
          type: string
          description: "Backstage owner (e.g. user:guest or group:platform-engineering)"
          ui:field: EntityPicker
          ui:options:
            catalogFilter:
              kind: [User, Group]
            allowArbitraryValues: true
        system:
          title: System
          type: string
          description: Backstage System this component belongs to
          ui:field: EntityPicker
          ui:options:
            catalogFilter:
              kind: System
            allowArbitraryValues: true

    - title: Container Registry
      required: [quayNamespace]
      properties:
        quayNamespace:
          title: Quay Registry + Namespace
          type: string
          description: >-
            Full registry host and organization path for the built image
            (e.g. registry-quay-quay-operator.apps.cluster.example.com/quayadmin)

  steps:
    - id: fetchSource
      name: Fetch Application Skeleton
      action: fetch:template
      input:
        url: ./skeleton
        values:
          name: ${{ parameters.name }}
          description: ${{ parameters.description }}
          owner: ${{ parameters.owner }}
          system: ${{ parameters.system }}
          quayNamespace: ${{ parameters.quayNamespace }}
          repoUrl: https://${{ globals.gitlabHost }}/software-factory/apps/${{ parameters.name }}
          gitopsRepoUrl: https://${{ globals.gitlabHost }}/software-factory/apps/${{ parameters.name }}-gitops
          devspacesUrl: https://${{ globals.devspacesHost }}/#https://${{ globals.gitlabHost }}/software-factory/apps/${{ parameters.name }}

    - id: publishSource
      name: Publish Application Repository
      action: publish:gitlab
      input:
        repoUrl: ${{ globals.gitlabHost }}?owner=software-factory%2Fapps&repo=${{ parameters.name }}
        description: ${{ parameters.description }}
        defaultBranch: main
        gitCommitMessage: "feat: initial scaffold from golden path template"

    - id: fetchGitops
      name: Fetch GitOps Skeleton
      action: fetch:template
      input:
        url: ./gitops-skeleton
        targetPath: gitops
        values:
          name: ${{ parameters.name }}
          quayNamespace: ${{ parameters.quayNamespace }}
          gitopsRepoUrl: https://${{ globals.gitlabHost }}/software-factory/apps/${{ parameters.name }}-gitops

    - id: publishGitops
      name: Publish GitOps Repository
      action: publish:gitlab
      input:
        repoUrl: ${{ globals.gitlabHost }}?owner=software-factory%2Fapps&repo=${{ parameters.name }}-gitops
        description: "GitOps manifests for ${{ parameters.name }}"
        defaultBranch: main
        sourcePath: gitops
        gitCommitMessage: "feat: initial gitops scaffold"

    - id: createArgoApp
      name: Create ArgoCD Application
      action: http:backstage:request
      input:
        method: POST
        path: /api/proxy/argocd/api/v1/applications
        headers:
          Content-Type: application/json
        body:
          metadata:
            name: ${{ parameters.name }}-dev
            namespace: openshift-gitops
          spec:
            project: apps
            source:
              repoURL: https://${{ globals.gitlabHost }}/software-factory/apps/${{ parameters.name }}-gitops
              targetRevision: main
              path: overlays/dev
            destination:
              server: https://kubernetes.default.svc
              namespace: ${{ parameters.name }}-dev
            syncPolicy:
              automated:
                prune: true
                selfHeal: true
              syncOptions:
                - CreateNamespace=true

    - id: register
      name: Register in Catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.publishSource.output.repoContentsUrl }}
        catalogInfoPath: /catalog-info.yaml

  output:
    links:
      - title: Source Repository
        url: ${{ steps.publishSource.output.remoteUrl }}
        icon: gitlab
      - title: GitOps Repository
        url: ${{ steps.publishGitops.output.remoteUrl }}
        icon: gitlab
      - title: Open in Catalog
        url: ${{ steps.register.output.entityRef }}
        icon: catalog
EOF
)
TEMPLATE_CONTENT_B64=$(printf '%s' "${TEMPLATE_CONTENT}" | base64 | tr -d '\n')

curl -skf --max-time 15 \
  -X POST "${GITLAB_URL}/api/v4/projects/${CATALOG_ID}/repository/files/template.yaml" \
  -H "Authorization: Bearer ${OAUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"branch\":\"main\",\"encoding\":\"base64\",\"content\":\"${TEMPLATE_CONTENT_B64}\",\"commit_message\":\"Initial template.yaml\"}" \
  > /dev/null

echo "Done. GitLab group structure initialized:"
echo "  software-factory/ (id=${SF_ID})"
echo "    platform/       (id=${PLATFORM_ID})"
echo "      software-factory-catalog (id=${CATALOG_ID})"
echo "    apps/           (id=${APPS_ID})"
