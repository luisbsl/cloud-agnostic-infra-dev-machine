# Operational Excellence: Multi-Tier Platform Bootstrap Runbooks

## 1. Pre-Flight Software Requirements Verification

Prior to initializing playbooks, verify that your host workstation satisfies the minimal requirements detailed in the [Software Requirements & Dependency Mapping Matrix](03-dependencies.md). The local host environment requires **ONLY** Docker Engine, a POSIX Shell, and Git.

```bash
# Verify local host software dependencies for sandbox execution compatibility
bash scripts/check-requirements.sh
```

## 2. Initializing the Platform Infrastructure Core via the Sandbox Container

To ensure total decoupling from the developer workstation, native host toolchains are entirely barred from execution. The entire platform configuration loop is orchestrated exclusively inside the **Ephemeral Sandbox Container** using our synchronous wrapper driver.

Run the master bootstrap playbook by routing the commands directly through the sandbox wrapper:

```bash
# 1. Download and install necessary Galaxy components inside the container context
bash scripts/sandbox-run.sh "ansible-galaxy collection install -r playbooks/requirements.yml"

# 2. Execute compilation pipelines, verify capacity profiles, and spin up the Kuma SDN network
bash scripts/sandbox-run.sh "ansible-playbook playbooks/bootstrap-platform.yml --extra-vars 'mesh_name=platform-simulation-vpc'"
```

## 3. Programmatically Applying GitHub Repository Rulesets via Containerized GH CLI

To assert Gitflow branch barriers securely without clicking through web panels or installing the GitHub CLI natively on the host, execute the ruleset payload operation inside the isolated control plane:

```bash
# Post the ruleset payload directly to repository endpoints using the embedded GitHub CLI
bash scripts/sandbox-run.sh "gh api --method POST -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' /repos/luisbsl/cloud-agnostic-infra-dev-machine/rulesets --input docs/compiled-manifests/governance/protect-gitflow.json"
```

## 4. Target Component Execution via Task Tags

If modifying specific elements of the infrastructure, developers can leverage task tagging patterns inside the sandbox wrapper to narrow execution scopes safely:

```bash
# Execute ONLY the "render" compilation step inside the container to evaluate manifests
bash scripts/sandbox-run.sh "ansible-playbook playbooks/bootstrap-platform.yml --tags 'render'"

# Execute ONLY the GitHub repository ruleset configuration task blocks
bash scripts/sandbox-run.sh "ansible-playbook playbooks/bootstrap-platform.yml --tags 'github-setup'"
```

When execution terminates, the container runtime layer auto-destructs via the `--rm` flag, scaling compute and memory draw back to absolute zero.
