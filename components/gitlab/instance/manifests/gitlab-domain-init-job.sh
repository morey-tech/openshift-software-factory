#!/usr/bin/env bash
# Discovers the cluster apps domain from the OpenShift ingress config and
# patches it into the GitLab CR's spec.chart.values.global.hosts.domain field.
#
# Idempotent: exits cleanly if the domain is already set.
# See docs/decisions/0022-runtime-apps-domain-discovery-for-gitlab.md
set -euo pipefail

NAMESPACE="gitlab-system"
CR_NAME="gitlab"

echo "Checking if domain is already set on GitLab CR..."
CURRENT_DOMAIN=$(kubectl get gitlab "${CR_NAME}" -n "${NAMESPACE}" \
  -o jsonpath='{.spec.chart.values.global.hosts.domain}' 2>/dev/null || true)

if [[ -n "${CURRENT_DOMAIN}" ]]; then
  echo "Domain already set to '${CURRENT_DOMAIN}', nothing to do."
  exit 0
fi

echo "Discovering apps domain from cluster ingress config..."
APPS_DOMAIN=$(kubectl get ingresses.config.openshift.io cluster \
  -o jsonpath='{.spec.domain}')

if [[ -z "${APPS_DOMAIN}" ]]; then
  echo "ERROR: could not determine apps domain from cluster ingress config" >&2
  exit 1
fi
echo "Discovered appsDomain: ${APPS_DOMAIN}"

kubectl patch gitlab "${CR_NAME}" -n "${NAMESPACE}" --type=merge \
  --patch "{\"spec\":{\"chart\":{\"values\":{\"global\":{\"hosts\":{\"domain\":\"${APPS_DOMAIN}\"}}}}}}"

echo "GitLab domain set to: ${APPS_DOMAIN}"
