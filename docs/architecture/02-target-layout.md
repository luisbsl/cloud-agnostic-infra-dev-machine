# Target Architecture and Multi-Tier Interface Map

## 1. Multi-Tier Service Sizing Boundaries

Resources fluctuate dynamically within strict maximum limits based on active platform routing traffic managed via Ansible cgroup definitions:

| Simulated Service Tier         | Engine Mechanism                         | Max vCPU Cap | Max RAM Cap | Network Invariant Scope                             |
| :----------------------------- | :--------------------------------------- | :----------- | :---------- | :-------------------------------------------------- |
| **Computing Fabric (4 Nodes)** | On-Demand Container Clusters             | 6 Cores      | 12 GB       | Managed Kuma Data-Plane Proxy Workspace             |
| **Integrated Ingress Gateway** | Kuma Gateway Mode (Envoy Edge Proxy)     | 1 Core       | 2 GB        | Edge Host Port Bindings & Path Translation Policies |
| **Kuma SDN Control Plane**     | Universal Single-Container Control Plane | 1 Core       | 2 GB        | Centralized Multi-Mesh Virtual VPC Topology         |
| **TOTAL ECOSYSTEM CEILING**    | **Elastic Platform Capacity Profile**    | **8 Cores**  | **16 GB**   | **Ansible-Orchestrated Software-Defined Network**   |

For the granular programmatic layout and block interaction model mapping these boundaries, see [Target System Design Blueprint](03-system-design.md).

## 2. Decoupled Service Routing Topology

Traffic paths are entirely software-defined and encapsulated inside encrypted mTLS proxy tunnels, keeping all operations fully insulated from the workstation host's physical adapters:

[ Developer Workstation Host Hardware Pool ]  
│  
└── 🎛️ Ansible Orchestration Control Plane (`playbooks/bootstrap-platform.yml`)  
 │  
 └── 🔐 CNCF Kuma Universal Software-Defined VPC Network Core (Central Control Plane)  
 └── [ Logical VPC Boundary: mesh = platform-simulation-vpc ]  
 │  
 ├── 🛜 TIER 2 & 3: INTEGRATED KUMA GATEWAY MODE INGRESS EDGE  
 │ └── 🌐 Exposes Edge Proxies (Binds to Local Host Edge Ports via Envoy)  
 │  
 └── 🏢 TIER 4: CLOUD-AGNOSTIC KUBERNETES WORKLOAD MESH (Envoy Data-Plane)  
 ├── 🖥️ control-01.cloud.internal ──► Cluster API Plane / Kuma Control Plane Sync  
 ├── 🖥️ worker-01.cloud.internal ──► Workload Container Runtime / Envoy Sidecar (`tier: data`)  
 ├── 🖥️ worker-02.cloud.internal ──► Workload Container Runtime / Envoy Sidecar (`tier: data`)  
 └── 🖥️ utility-01.cloud.internal ──► Core Storage Depot / Internal Kuma ZoneIngress Proxy
