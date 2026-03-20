---
status: accepted
date: 2026-03-20
---

# Use Git Files Generator for ApplicationSets

## Context and Problem Statement

The two ApplicationSets (operators and operands) need to generate one Argo CD Application per component folder. Each generated Application must target the correct OpenShift namespace. However, OpenShift operators are often picky about which namespace they are deployed into, and the required namespace frequently doesn't match a human-friendly folder name.

For example, OpenShift Virtualization's operator is named `kubevirt-hyperconverged` and must be deployed into the `openshift-cnv` namespace. If we named the folder `openshift-virtualization` (human-friendly), we couldn't derive the correct namespace from the folder path. If we named it `openshift-cnv`, the folder name becomes unhelpful.

## Decision Drivers

* OpenShift operators require specific namespaces that don't always match intuitive component names
* Folder names should remain human-readable and descriptive
* Namespace configuration should be salient — visible right next to the component's manifests, not buried in a centralized ApplicationSet definition

## Considered Options

* Git directory generator with folder name as namespace
* Git directory generator with templatePatch overrides
* Git files generator with config.json per component folder

## Decision Outcome

Chosen option: "Git files generator with config.json", because it decouples the folder name from the target namespace and keeps the configuration co-located with the component's manifests.

Each `operator/` and `instance/` folder contains a `config.json` with at minimum:

```json
{
  "name": "openshift-virtualization",
  "namespace": "openshift-cnv"
}
```

The ApplicationSets use the git files generator to discover these files and template the Application name, destination namespace, and source path from the config values.

### Consequences

* Good, because folder names stay human-friendly and descriptive
* Good, because namespace and metadata are co-located with the component manifests — easy to find and review
* Good, because additional per-component metadata can be added to config.json in the future without changing the ApplicationSet
* Neutral, because each new component folder requires a config.json file (minimal overhead)

## Pros and Cons of the Options

### Git directory generator with folder name as namespace

The directory generator scans for folders matching a glob and provides `{{path}}` and `{{path.basename}}` as template parameters.

* Good, because no extra files needed — just the folder structure
* Bad, because folder names must match OpenShift namespaces exactly, leading to unhelpful names like `openshift-cnv` instead of `openshift-virtualization`
* Bad, because no way to attach additional per-component metadata

### Git directory generator with templatePatch overrides

Use the directory generator but add `templatePatch` blocks on the ApplicationSet to override the namespace for components that don't match.

* Good, because folder names can stay human-friendly
* Bad, because namespace overrides are centralized in the ApplicationSet definition, far from the component manifests
* Bad, because the templatePatch grows with each exception, becoming harder to maintain

### Git files generator with config.json

The files generator discovers JSON files matching a glob and makes all JSON keys available as template parameters.

* Good, because each component declares its own namespace alongside its manifests
* Good, because folder names are fully decoupled from deployment metadata
* Good, because extensible — additional fields can be added per component without changing the ApplicationSet
* Neutral, because requires a config.json in every component folder
