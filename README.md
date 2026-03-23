# Enterprise Software Factory on OpenShift

A reference implementation for bootstrapping an OpenShift cluster into a fully functional, GitOps-managed software factory.

## What is this?

The Software Factory shifts an IT organization's focus from infrastructure hosting to developer enablement. It provides a "Golden Path" that abstracts infrastructure complexity, enforces security guardrails, and gives developers a self-service experience across the entire SDLC.

See [docs/capabilities.md](docs/capabilities.md) for a full breakdown of capabilities by SDLC phase.

## Status

**Under active development.** Core GitOps bootstrap, operators, and several operands are complete. Developer Hub configuration, optional org-wide services, and the golden-path template are in progress. See the [Project Plan](docs/PLAN.md) for the full phase-by-phase breakdown.

## How it works

```
Ansible Playbook
  └── Installs OpenShift GitOps Operator
        └── Creates Root Argo CD Application
              └── Deploys 2 ApplicationSets
                    ├── Operators AppSet  → components/*/operator/config.json
                    └── Operands AppSet   → components/*/instance/config.json
```

Adding a component means adding a folder under `components/` with `operator/` and/or `instance/` subdirectories, each containing a `config.json`. The ApplicationSets use the git files generator to discover these and template Argo CD Applications automatically.

## Repository Structure

```
ansible/          # Bootstrap playbook, teardown playbook, and root Application manifest
bootstrap/        # ApplicationSets (operators + operands) — managed by Argo CD
components/       # Per-component operator and instance manifests
docs/             # Architecture docs, ADRs, and project plan
```

The root Argo CD Application is applied by the Ansible playbook rather than stored in `bootstrap/`, avoiding a circular self-management dependency. See [ADR-0002](docs/decisions/0002-deploy-root-application-with-ansible.md) for the rationale.

## Getting Started

See the [Ansible README](ansible/README.md) for prerequisites, inventory setup, and step-by-step instructions to bootstrap the cluster.

## Documentation

- [Platform Capabilities](docs/capabilities.md)
- [Project Plan](docs/PLAN.md)
- [Architecture Decision Records](docs/decisions/)

### Architecture Decision Records

Key design choices are captured as ADRs in [docs/decisions/](docs/decisions/). Each ADR documents the context, the options considered, and the rationale for the chosen approach. When a decision affects how you extend or operate this repository, the relevant ADR is referenced inline. Reading the ADRs is the fastest way to understand *why* the system is structured the way it is, not just *how* it works.

## License

Distributed under the Apache 2.0 License. See [LICENSE](LICENSE) for more information.
