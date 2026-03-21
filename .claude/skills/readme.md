# README Skill

Keep README.md files up to date when files in their directory are added, removed, or changed.

## When to apply

After any change to files in a directory — adding, removing, or modifying files — check whether a `README.md` exists in that directory. If it does, update it to reflect the change. Do this proactively without being asked, as part of completing the task.

## What to update

1. **Contents table** — Add, remove, or rename rows to match the current files in the directory. Each row describes a file's purpose concisely.

2. **Contextual sections** — Update any prose sections that describe configuration, behaviour, or intent affected by the change. For example:
   - If a new manifest is added, describe what it does
   - If an option changes (e.g. RBAC policy, channel, namespace), update the relevant bullet or section
   - If a file is removed, remove references to it
   - If an ADR comment is added to a file, you do not need to duplicate the ADR rationale — a brief description is enough

3. **Do not** rewrite sections that are unaffected by the change.

## README style (match existing conventions)

- **Title:** `# Component Name — Subfolder` (e.g. `# OpenShift GitOps — Instance`)
- **Intro:** one sentence stating how the folder is managed (e.g. "This folder is managed by the `operands` ApplicationSet.")
- **Contents table:**

  ```markdown
  ## Contents

  | File | Purpose |
  |------|---------|
  | `filename.yaml` | One-line description |
  ```

- **Contextual sections:** `##` headings, bullet lists for configuration details, plain prose for rationale
- Keep it concise — READMEs are for orientation, not exhaustive documentation

## If no README exists

Do not create one unless the user explicitly asks. Only update existing READMEs.
