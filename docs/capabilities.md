# Architecture & Capabilities across the SDLC

The Software Factory's capabilities are designed to remove friction and embed automated security natively into every phase of the SDLC.

## 1. Plan & Develop Phase

*Focus: Removing friction for developers, bypassing hardware constraints, and accelerating onboarding to start writing code immediately.*

### The "Shopping Cart" Experience & Standardized Blueprints

**The Need:** Developers need a centralized portal to select pre-approved, compliant project templates. When selected, the platform must automatically scaffold the secure workspace, initialize source control repositories, and generate the necessary CI/CD pipelines without manual IT intervention.

* **Core Tooling:** **Red Hat Developer Hub (Backstage)**
  * Acts as the central developer portal and service catalog.
  * Utilizes Software Templates to quickly spin up new projects with enterprise standards built-in from day one.

### Secure, Instant-On Cloud Workspaces

**The Need:** Developers and external contractors often face severe constraints from locked-down local laptops, restrictive firewalls, and limited VDI. They need secure, browser-based development environments that run completely within the corporate network to write and test code.

* **Core Tooling:** **Red Hat OpenShift Dev Spaces**
  * Provides instant, containerized, browser-based IDEs running directly inside the cluster.
  * Ensures environments are consistent across the entire engineering team ("it works on my machine" becomes "it works on the platform").

## 2. Build, Test & Release Phase

*Focus: Automating code compilation, enforcing shift-left security scanning, and ensuring code provenance before releasing artifacts.*

### Automated, Opinionated Pipelines (Continuous Integration)

**The Need:** Organizations require automated pipelines that enforce standard build paths. Applications must be built, tested, and packaged consistently without relying on manual runbooks or fragmented scripts.

* **Core Tooling:** **Red Hat OpenShift Pipelines (Tekton)**
  * Executes Kubernetes-native, serverless CI/CD pipelines.
  * Integrates seamlessly with enterprise source control systems to trigger builds automatically upon code commits, running unit tests and functional validations.

### Secure Artifact Management & Image Provenance

**The Need:** Container images and dependencies must be pulled from known, secure internal locations rather than directly from public registries, and newly built release packages must be stored securely.

* **Core Tooling:** **Red Hat Quay / Enterprise Artifact Registries**
  * Provides a secure, private registry for storing and distributing container images.
  * Automatically scans stored images for vulnerabilities before they are released for deployment.

## 3. Deliver & Deploy Phase

*Focus: Automating the path to production and enforcing deployment control gates to stop vulnerable code.*

### "Shift-Left" Deployment Guardrails

**The Need:** Security cannot be an afterthought or a manual checklist. The platform must embed automated compliance guardrails that evaluate configurations and artifacts right before they enter target environments.

* **Core Tooling:** **Red Hat Advanced Cluster Security (ACS)**
  * Acts as a control gate during the deployment phase.
  * Instantly identifies vulnerabilities across the CI/CD pipeline and actively blocks the deployment of non-compliant images or misconfigured workloads from reaching the operational environment.

## 4. Operate & Monitor Phase

*Focus: Cloud-agnostic hosting, multi-tenancy, and continuous runtime observation and feedback.*

### Cloud-Agnostic Abstraction & "Run Anywhere" Flexibility

**The Need:** To avoid commercial vendor lock-in and optimize hosting costs, the business needs a consistent operational layer. Applications must be built once and deployed anywhere.

* **Core Tooling:** **Red Hat OpenShift Container Platform (OCP)**
  * Provides the underlying enterprise Kubernetes engine for the Operate phase.
  * Offers absolute consistency regardless of the underlying infrastructure (AWS, Azure, GCP, VMware, or Bare Metal).

### End-to-End Application Ownership & Multi-Tenancy

**The Need:** A single enterprise platform must securely host hundreds of disparate applications built by different internal teams and third-party integrators.

* **Core Tooling:** **OpenShift Namespaces, Projects, and RBAC**
  * Enforces strict multi-tenancy and resource quotas.
  * Uses native Role-Based Access Control (RBAC) integrated with corporate SSO to ensure developers only have access to their approved namespaces.

### Continuous Runtime Security & Feedback

**The Need:** Threats evolve even after software is deployed. The factory requires continuous operational monitoring to detect anomalies and feed insights back to the planning phase.

* **Core Tooling:** **Red Hat Advanced Cluster Security (ACS)**
  * Monitors running workloads (Runtime phase) for anomalous behavior, zero-day exploits, and unauthorized executions.
  * Generates immediate feedback loops for development and security teams to patch and re-trigger the SDLC.
