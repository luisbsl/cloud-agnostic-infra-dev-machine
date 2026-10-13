# Operational Excellence: Ephemeral Sandbox Container Architecture

This guide details the technical design, execution mechanics, and containerized runtime configuration for the platform sandbox environment.

## 1. Sandbox Architecture Mapping

The Sandbox Container abstracts the orchestration plane from the host hardware. Commands executed via `scripts/sandbox-run.sh` launch a transient container with mounted sockets, providing access to the host's Docker engine while executing all logic inside the insulated container image.

```mermaid
graph TD
    subgraph HostWorkstation ["Developer Host Machine (Requires ONLY Docker, Shell, Git)"]
        A[Developer Terminal] -->|Invokes| B[scripts/sandbox-run.sh]
        C[Host Docker Daemon /var/run/docker.sock]
        D[Host Workspace Directory $PWD]
    end

    subgraph SandboxContainer ["Ephemeral Dev Sandbox Container (Dockerfile.dev-sandbox)"]
        E[Ansible-Core 2.21.5]
        F[Ansible Galaxy + community.docker]
        G[JQ Processor 1.8.2]
        H[GitHub CLI 'gh' 2.101.0]
        I[Python 3.12 + PyYAML]
    end

    subgraph TargetContainers ["Platform Infrastructure Tiers (Provisioned on Host Docker)"]
        J[Tier 1: Elastic Container Computing Service]
        K[Tier 2/3: Ingress & API Gateway]
        L[Tier 4: Managed Kubernetes Workloads]
    end

    B -->|1. Mounts Workspace & Docker Socket| SandboxContainer
    SandboxContainer -->|2. Reads Blueprints & Executes Playbooks| E
    E -->|3. Issues Container Mutations via Mounted Socket| C
    C -->|4. Provisions Simulated Tiers| TargetContainers
```

## 2. Strategic Alignment

This operational setup satisfies the mandate defined under [ADR-0005](../adr/0005-adopt-containerized-sandbox-dev-environment.md). By executing all workflows synchronously within an interactive or single-invocation container with `--rm` flags, the background footprint drops completely to zero when idle.
