---
status: accepted
date: 2026-03-20
---

# Use MADR for Architecture Decision Records

## Context and Problem Statement

As we build out the OpenShift Software Factory, we need a way to document the architectural decisions we make along the way. These records should be lightweight, version-controlled alongside the code, and easy for the team to author and review.

## Decision Drivers

* Decisions should live in the repo, not in external wikis or documents
* The format should be simple enough that it doesn't become a barrier to writing them
* Records should be easy to review in pull requests

## Considered Options

* MADR (Markdown Any Decision Records)
* Informal notes in the README or PLAN.md
* No formal decision tracking

## Decision Outcome

Chosen option: "MADR", because it provides a lean, structured template that lives in the repo as plain markdown. It strikes the right balance between enough structure to be useful and low enough friction to actually get written.

### Consequences

* Good, because decisions are captured consistently and are easy to find in `docs/decisions/`
* Good, because the markdown format works naturally with Git and pull request review workflows
* Neutral, because it requires contributors to follow the template convention

## More Information

* MADR project: <https://adr.github.io/madr/>
* ADRs are stored in `docs/decisions/` and follow the naming convention `NNNN-title-with-dashes.md`
