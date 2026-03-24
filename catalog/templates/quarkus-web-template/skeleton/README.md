# ${{ values.name }}

${{ values.description }}

## Getting Started

### Prerequisites

- Java 21+
- Maven 3.9+

### Running locally (dev mode)

```bash
mvn quarkus:dev
```

The application starts at http://localhost:8080.

| Endpoint | Description |
|---|---|
| `GET /hello` | Greeting endpoint |
| `GET /q/health` | Aggregated health check |
| `GET /q/health/live` | Liveness probe |
| `GET /q/health/ready` | Readiness probe |

### Building

```bash
mvn package -DskipTests
```

### Building the container image

```bash
podman build -f Containerfile -t ${{ values.name }}:latest .
```

## Ownership

- **Owner**: ${{ values.owner }}
- **System**: ${{ values.system }}
