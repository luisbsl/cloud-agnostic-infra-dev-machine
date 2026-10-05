# Operational Excellence: Multi-Tier Platform Bootstrap Runbooks

## 1. Initializing the Platform Infrastructure Core via Ansible

Rather than forcing developers to manually coordinate shell-level compilation scripts, container engine definitions, and gateway routing parameters, the entire platform lifecycle is driven via a single, idempotent Ansible execution.

Run the master bootstrap playbook from the root of the repository:

```bash
	# 1. Install necessary external community collections (e.g., community.docker)
	ansible-galaxy collection install -r playbooks/requirements.yml

	# 2. Execute compilation pipelines, verify capacity profiles, and bring up the Kuma SDN network
	ansible-playbook playbooks/bootstrap-platform.yml --extra-vars "mesh_name=platform-simulation-vpc"
```

## 2. Programmatically Applying GitHub Repository Rulesets via GH CLI

To assert Gitflow branch barriers securely without clicking through web panels, execute the following `gh api` loop using our declarative definition block:

```bash
# Verify active authentication status against GitHub APIs
gh auth status

# POST the ruleset payload directly to the repository endpoints
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/luisbsl/cloud-agnostic-infra-dev-machine/rulesets \
  --input ../../docs/compiled-manifests/governance/protect-gitflow.json
```

## 3. Target Component Execution via Task Tags

If modifying specific elements of the infrastructure, developers can leverage Ansible's native tagging engine to narrow execution scopes safely:

```bash
# Execute ONLY the "render" compilation step to evaluate metadata tags locally
ansible-playbook playbooks/bootstrap-platform.yml --tags "render"

# Execute ONLY the GitHub repository ruleset configuration task blocks
ansible-playbook playbooks/bootstrap-platform.yml --tags "github-setup"
```
