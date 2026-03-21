# ADR Skill

Create and reference Architecture Decision Records (ADRs) for this project.

## When invoked

The user wants to create a new ADR, or wants you to create one as part of a change.

## Steps

1. **Determine the next number**: Glob `docs/decisions/*.md` and find the highest `NNNN` prefix. Increment by 1, zero-padded to 4 digits.

2. **Choose a filename**: `docs/decisions/NNNN-short-title-with-dashes.md`

3. **Write the ADR** using MADR format (see `docs/decisions/adr-template.md` for the template and `docs/decisions/0000-use-madr-for-architecture-decisions.md` for project intent):

```markdown
---
status: accepted
date: YYYY-MM-DD
---

# Title

## Context and Problem Statement

...

## Decision Drivers

* ...

## Considered Options

* ...

## Decision Outcome

Chosen option: "...", because ...

### Consequences

* Good, because ...
* Bad, because ...

### Confirmation

...

## Pros and Cons of the Options

### Option name

* Good, because ...
* Bad, because ...
```

4. **Add comments in related files** linking to the new ADR wherever the decision is implemented:
   - YAML/config files: `# See docs/decisions/NNNN-title.md`
   - Ansible tasks: add a comment above the relevant task
   - Use a path relative to the file being commented, or the repo-root-relative path `docs/decisions/...`

5. **If superseding an existing ADR**, update the superseded ADR's frontmatter:
   `status: superseded by [ADR-NNNN](NNNN-title.md)`

## Conventions (from ADR 0000)

- ADRs live in `docs/decisions/` alongside the code — not in external wikis
- Naming: `NNNN-title-with-dashes.md` (four-digit zero-padded number)
- Format: MADR (lean structured markdown)
- Every significant architectural or tooling decision gets an ADR
- Decisions should be easy to find in pull request review
