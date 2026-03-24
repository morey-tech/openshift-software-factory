---
status: accepted
date: 2026-03-24
---

# Quarkus Fast-Jar Packaging for the Golden Path Skeleton Containerfile

## Context and Problem Statement

The golden path template skeleton (`catalog/templates/quarkus-web-template/skeleton/Containerfile`)
must produce a runnable OCI image from a Quarkus application source tree. The Quarkus Maven plugin
supports three output formats: fast-jar (the default), über-jar, and native binary. Each produces a
different artifact layout that requires a different `COPY` pattern in the Containerfile and has
different build-time and runtime characteristics. Which packaging format should the skeleton use?

## Decision Drivers

* The Containerfile is built by the `buildah` task in the `build-and-push` Tekton Pipeline — build
  time inside a pipeline pod matters; long builds increase feedback latency for developers
* The image is deployed to OpenShift via ArgoCD — startup time affects rolling-update speed and
  readiness probe behaviour
* The skeleton is a learning artefact as well as a functional template — the Containerfile should
  be comprehensible to developers who are new to Quarkus
* Red Hat Universal Base Images must be used to satisfy OpenShift SCC requirements and remain
  within Red Hat's support boundary

## Considered Options

* **Fast-jar** — default Quarkus output; layered JAR layout under `target/quarkus-app/`
* **Über-jar** — single fat JAR; requires `-Dquarkus.package.jar.type=uber-jar`
* **Native binary** — GraalVM AOT compilation; requires a GraalVM builder image

## Decision Outcome

Chosen option: **Fast-jar**, because it is the Quarkus default (zero extra configuration),
produces a layer-cache-friendly image, and avoids the significant build-time cost of native
compilation inside a CI pipeline pod.

### How it works

The Maven build produces a `target/quarkus-app/` directory with four components that must all be
present at runtime:

| Path | Contents |
|---|---|
| `quarkus-run.jar` | Thin launcher JAR |
| `lib/` | All dependency JARs |
| `app/` | Application classes |
| `quarkus/` | Quarkus framework classes |

The Containerfile copies all four paths from the builder stage:

```dockerfile
COPY --from=builder /build/target/quarkus-app/lib/            ./lib/
COPY --from=builder /build/target/quarkus-app/quarkus-run.jar ./quarkus-run.jar
COPY --from=builder /build/target/quarkus-app/app/            ./app/
COPY --from=builder /build/target/quarkus-app/quarkus/        ./quarkus/
```

Omitting any of the four paths causes a `ClassNotFoundException` at runtime.

### Consequences

* Good, because no `pom.xml` changes are needed — fast-jar is the Quarkus Maven plugin default
* Good, because `lib/` changes infrequently (only when dependencies change), so the `lib/`
  layer is cached across most rebuilds — this speeds up both `buildah` pushes and image pulls
* Good, because `ubi9/openjdk-21-runtime` (JRE-only) can be used as the runtime base, keeping
  the final image smaller and within Red Hat support
* Bad, because the Containerfile requires 4 `COPY` statements instead of 1 — this is surprising
  to developers unfamiliar with the fast-jar layout

## Pros and Cons of the Options

### Fast-jar

* Good, because it is the Maven plugin default — no extra flags or properties needed
* Good, because the layered layout enables OCI layer caching of dependency JARs
* Good, because startup time is fast (~250 ms for a minimal Quarkus app)
* Bad, because 4 `COPY` statements are required; the layout is not self-explanatory

### Über-jar

* Good, because a single `COPY target/quarkus-app/*-runner.jar` is sufficient
* Good, because familiar to developers who know the Spring Boot fat-JAR model
* Bad, because all classes are merged into one layer — no dependency caching benefit
* Bad, because requires opt-in: `-Dquarkus.package.jar.type=uber-jar` in the build command
  or an explicit property in `pom.xml`, diverging from Quarkus defaults

### Native binary

* Good, because produces the smallest possible image (no JVM required in the runtime stage)
* Good, because sub-10 ms startup time
* Bad, because requires a GraalVM builder image (`ubi9/graalvm-community` or Mandrel),
  substantially larger than `ubi9/openjdk-21`
* Bad, because native compilation takes 3–10 minutes per build — unacceptable latency in a
  developer inner-loop CI pipeline
* Bad, because reflection configuration must be maintained for libraries that use it
