## Summary & Context

<!-- Describe the scope and intent of the change. Link related issues or tracking items. -->

## Type of Change

- [ ] `feature/*` - New platform capability or repository feature[cite: 1]
- [ ] `fix/*` - Non-urgent correction[cite: 1]
- [ ] `docs/*` - Documentation-only change[cite: 1]
- [ ] `infra/*` - Infrastructure or shared-platform configuration[cite: 1]
- [ ] `release/*` - Optional versioned baseline preparation[cite: 1]
- [ ] `hotfix/*` - Urgent baseline correction[cite: 1]

## Validation & Testing

<!-- Describe how this change was validated. Include commands run locally. -->

- [ ] Verified diff whitespace (`git diff --check`)[cite: 1]
- [ ] Evaluated JSON schema parsing (`jq empty docs/compiled-manifests/governance/protect-gitflow.json`)[cite: 3]

## Infrastructure Impact & Safety Boundary

<!-- Does this change impact infrastructure state? Confirm safety boundary compliance. -->

- [ ] **No Unprivileged Execution**: Confirmed no Terraform apply, `kubectl` mutation, or credential modification is present in CI[cite: 1].
- [ ] **Rollback Plan**: Clear plan specified in case revert is required[cite: 1].

## Review Checklist

- [ ] Self-review performed and recorded[cite: 1]
- [ ] Branch targets correct target (`develop` or `main`) according to workflow specs[cite: 1]
