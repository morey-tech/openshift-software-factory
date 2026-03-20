# Enterprise Software Factory on OpenShift

A reference implementation for bootstrapping an OpenShift cluster into a fully functional, GitOps-managed software factory.

## What is this?

The Software Factory shifts an IT organization's focus from infrastructure hosting to developer enablement. It provides a "Golden Path" that abstracts infrastructure complexity, enforces security guardrails, and gives developers a self-service experience across the entire SDLC.

See [docs/capabilities.md](docs/capabilities.md) for a full breakdown of capabilities by SDLC phase.

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
ansible/          # Bootstrap playbook and inventory
bootstrap/        # Root Argo CD Application and ApplicationSets
components/       # Per-component operator and instance manifests
docs/             # Architecture docs, ADRs, and project plan
```

## Getting Started

Run the Ansible bootstrap playbook to install the OpenShift GitOps operator and deploy the root Argo CD application:

```bash
cd ansible
ansible-playbook bootstrap.yaml
```

## Documentation

- [Platform Capabilities](docs/capabilities.md)
- [Project Plan](docs/PLAN.md)
- [Architecture Decision Records](docs/decisions/)

## License

Distributed under the Apache 2.0 License. See [LICENSE](LICENSE) for more information.
