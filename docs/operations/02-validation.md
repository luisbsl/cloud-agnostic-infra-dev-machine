# Operational Excellence: Integrated Multi-Tier Validation Frameworks

## 1. Triggering Remote Validation Tests via GitHub CLI

To kick off the repository validation actions workflows on-demand from your local terminal workspace without pushing empty commits, use the workflow dispatch tool:

```bash
# Execute the targeted test run against an active topic development branch
gh workflow run ci.yml --ref docs/update-runbook

# Monitor the execution status of the pipeline run directly inside the terminal
gh run list --workflow=ci.yml --limit 1
gh run watch
```

## 2. Automated Health & Integration Verification

Ansible provides a testing and validation runbook that issues non-destructive structural checks against live ingress paths and the SDN service discovery catalog:

```bash
	# Executes validation playbooks to confirm zero-trust contract delivery
	ansible-playbook playbooks/validate-platform.yml
```

## 3. Emergency Workspace Evacuation

If local memory thresholds are reached or an environment requires immediate teardown, execute the evacuation playbook to instantly clear all container footprints and return workstation utilization to zero:

```bash
	# Flushes active container boundaries, unlinks transient manifests, and cleans local state blocks
	ansible-playbook playbooks/teardown-platform.yml
```
