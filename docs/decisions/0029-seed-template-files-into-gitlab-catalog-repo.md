---
status: accepted
date: 2026-03-24
---

# Seed Template Files into GitLab Catalog Repo Instead of Pointing to GitHub

## Context and Problem Statement

The `gitlab-platform-init-job` seeds a `catalog-info.yaml` into the
`software-factory/platform/software-factory-catalog` GitLab repo at deploy time.
RHDH's `gitlabOrg` catalog provider discovers this file and registers whatever
entities it describes.

The initial implementation seeded a wrapper Backstage `Location` entity whose
`targets` array pointed to the golden path template's `catalog-info.yaml` on
GitHub (`raw.githubusercontent.com`). This means:

1. RHDH must reach the public internet to load the template on every catalog refresh.
2. The template version loaded is pinned to a specific branch/commit on GitHub, not to
   the version actually deployed on this cluster.
3. The discovery chain has an extra hop: seeded Location → GitHub Location → GitHub Template.

How should the golden path template be made available to RHDH in a way that is
self-contained, works air-gapped, and is consistent with the version deployed?

## Decision Drivers

* No runtime dependency on GitHub or any external network — the factory must work
  in restricted / air-gapped environments
* The template version discovered by RHDH should match the version that was deployed
* Minimal indirection — fewer network hops during RHDH catalog refresh
* Consistent with the existing pattern of the `gitlab-platform-init-job` owning all
  bootstrap content in `software-factory-catalog`

## Considered Options

* **Wrapper Location pointing to GitHub** — seed a `Location` whose `targets` entry
  is the `raw.githubusercontent.com` URL of the template's `catalog-info.yaml`
* **Wrapper Location pointing to on-cluster GitLab** — seed a `Location` whose
  `targets` entry points to the template's `catalog-info.yaml` within the same
  `software-factory-catalog` repo (requires also seeding that file)
* **Seed template files directly** — seed both `catalog-info.yaml` (a `Location`
  with `targets: [./template.yaml]`) and `template.yaml` (the `Template` entity)
  directly into `software-factory-catalog`; RHDH discovers them without any
  wrapper indirection

## Decision Outcome

Chosen option: **Seed template files directly**, because it eliminates the GitHub
runtime dependency, removes one level of Location indirection, and ensures the
in-cluster template is always the version that was built into this deployment.

### Implementation

The `gitlab-platform-init-job.sh` script seeds the catalog repo by:

1. Creating the `software-factory-catalog` project in GitLab **without** `initialize_with_readme` so the repo starts empty.
2. Shallow-cloning `https://github.com/morey-tech/openshift-software-factory` (this repo) into a temp directory.
3. Initialising a new local git repo, copying `catalog/templates/quarkus-web-template/` as the root, and pushing a single initial commit.

The files pushed mirror the template directory exactly:

| Path in catalog repo | Source in this repo |
|---|---|
| `catalog-info.yaml` | `catalog/templates/quarkus-web-template/catalog-info.yaml` |
| `template.yaml` | `catalog/templates/quarkus-web-template/template.yaml` |
| `skeleton/` | `catalog/templates/quarkus-web-template/skeleton/` |
| `gitops-skeleton/` | `catalog/templates/quarkus-web-template/gitops-skeleton/` |

`catalog/templates/quarkus-web-template/` is the single source of truth — no file
content is duplicated in the script.

When RHDH runs `fetch:template` with `url: ./skeleton`, Backstage constructs a
GitLab archive URL relative to the template's raw URL. Because the skeleton
directories are now committed to the repo, GitLab returns a valid tar archive
instead of a 404 HTML page (which was the previous failure mode).

### Consequences

* Good, because no runtime dependency on GitHub or any public CDN
* Good, because the template version in RHDH always matches the version in the deployed commit of this repo
* Good, because one fewer network hop during catalog refresh (Location → Template instead of Location → Location → Template)
* Good, because `fetch:template` steps resolve successfully — skeleton directories are present in the GitLab repo
* Good, because `catalog/templates/` is the single source of truth — no duplication in the script
* Neutral, because the init job performs a shallow clone of this repo at deploy time (one extra network call, but only during bootstrap)

## Pros and Cons of the Options

### Wrapper Location pointing to GitHub

* Good, because no duplication — single source of truth in this repo
* Bad, because requires internet access at RHDH catalog refresh time
* Bad, because the template version is tied to a GitHub branch, not the deployed cluster

### Wrapper Location pointing to on-cluster GitLab

* Good, because no internet dependency
* Bad, because requires the same duplication as the chosen option (template files
  must still be seeded into the GitLab repo)
* Bad, because adds an extra level of indirection (Location → Location → Template)
  compared to the chosen option

### Seed template files directly

* Good, because fully self-contained — no external URLs at any layer
* Good, because minimal indirection (Location → Template)
* Neutral, because the script is larger but the structure is straightforward
* Bad, because template.yaml must be kept in sync between two locations in this repo
