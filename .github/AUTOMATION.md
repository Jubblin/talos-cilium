# Automation Overview

This repository uses GitHub Actions workflows to automate version management and template generation
for Cilium and Tetragon deployments on Talos Linux.

## 🔄 Automation Flow

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Daily Automated Check                         │
│                   (00:00 UTC every day)                          │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │   update-versions.yml         │
        │   Checks GitHub releases:     │
        │   • cilium/cilium             │
        │   • cilium/tetragon           │
        └───────────┬───────────────────┘
                    │
                    ├─ No updates ──────────────┐
                    │                            │
                    └─ Updates found ───────┐   │
                                            │   │
                                            ▼   ▼
                        ┌─────────────────────────────────┐
                        │  Creates Pull Request           │
                        │  • Updates versions file        │
                        │  • Links to release notes       │
                        │  • Labels: dependencies         │
                        └────────┬────────────────────────┘
                                 │
                                 ▼
                        ┌─────────────────────────────────┐
                        │  Human Review & Merge           │
                        │  • Review release notes         │
                        │  • Check for breaking changes   │
                        │  • Approve and merge PR         │
                        └────────┬────────────────────────┘
                                 │
                                 ▼
                ┌────────────────┴────────────────┐
                │                                  │
                ▼                                  ▼
    ┌───────────────────────┐        ┌───────────────────────┐
    │ cilium-helm.yml       │        │ tetragon-helm.yml     │
    │ Generates:            │        │ Generates:            │
    │ • cilium-secure.yaml  │        │ • tetragon.yaml       │
    │ • cilium.yaml         │        │ • tetragon-single-    │
    │ • cilium-single-      │        │   node.yaml           │
    │   node.yaml           │        │                       │
    └──────────┬────────────┘        └──────────┬────────────┘
               │                                 │
               └────────────┬────────────────────┘
                            │
                            ▼
                ┌────────────────────────────┐
                │  Auto-commit Templates     │
                │  Templates updated in repo │
                └────────────────────────────┘
```

## 📋 Workflows Summary

### 1. Update Versions (`update-versions.yml`)

**Purpose:** Automatically detect and update Cilium/Tetragon versions

**Schedule:** Daily at 00:00 UTC

**Manual Trigger:** Available via Actions tab

**What it does:**

1. Fetches latest releases from GitHub
2. Compares with current versions
3. Creates PR if updates found
4. Includes release notes links

**Requirements:**

- `PAT_TOKEN` secret (for PR creation)
- Falls back to `GITHUB_TOKEN` if not set

### 2. Cilium Helm Generator (`cilium-helm.yml`)

**Purpose:** Generate Cilium Kubernetes manifests from Helm charts

**Triggers:**

- Changes to `versions` file
- Changes to workflow file itself
- Manual trigger

**Generates:**

- `cilium-secure.yaml` - Secure configuration
- `cilium.yaml` - Standard with encryption
- `cilium-single-node.yaml` - Single node optimized

**Configuration Variables:**

- `CILIUM_VALUES` - Base Helm values
- `CILIUM_ENCRYPT` - Encryption settings
- `CILIUM_SINGLE_OPERATOR` - Single node settings

### 3. Tetragon Helm Generator (`tetragon-helm.yml`)

**Purpose:** Generate Tetragon security observability manifests

**Triggers:**

- Changes to `versions` file
- Changes to workflow file itself
- Manual trigger

**Generates:**

- `tetragon.yaml` - Standard multi-node
- `tetragon-single-node.yaml` - Single node (1 replica)

## 🎯 Benefits

### Automation

- ✅ Daily checks for new releases
- ✅ Automatic template generation
- ✅ No manual version tracking needed

### Safety

- ✅ PR-based workflow for review
- ✅ Release notes included
- ✅ Git history of all changes

### Consistency

- ✅ Templates always match versions
- ✅ Standardized configurations
- ✅ Reproducible deployments

### Efficiency

- ✅ Reduces manual work
- ✅ Fast updates to latest versions
- ✅ Immediate availability of new features

## 🔧 Setup Requirements

### For Auto-Updates (update-versions.yml)

Create a Personal Access Token:

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate new token with scopes:
   - `repo` - Full repository access
   - `workflow` - Update workflows
3. Add as repository secret named `PAT_TOKEN`

### For Template Generation (cilium-helm.yml, tetragon-helm.yml)

Configure repository variables (Settings → Secrets and variables → Actions → Variables):

```yaml
CILIUM_VALUES: |
  --set key1=value1
  --set key2=value2

CILIUM_ENCRYPT: |
  --set encryption.enabled=true

CILIUM_SINGLE_OPERATOR: |
  --set operator.replicas=1
```

## 📊 Monitoring

### Check Workflow Status

```bash
# View recent workflow runs
gh run list --workflow=update-versions.yml

# View specific run
gh run view <run-id>

# Watch a running workflow
gh run watch
```

### Workflow Badges

Add to your README to show workflow status:

```markdown
![Update Versions](https://github.com/yourusername/talos-cilium/actions/workflows/update-versions.yml/badge.svg)
![Cilium Helm](https://github.com/yourusername/talos-cilium/actions/workflows/cilium-helm.yml/badge.svg)
![Tetragon Helm](https://github.com/yourusername/talos-cilium/actions/workflows/tetragon-helm.yml/badge.svg)
```

## 🐛 Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| PR creation fails | Missing PAT_TOKEN | Add PAT_TOKEN secret |
| Template generation fails | Invalid version | Check versions file format |
| Push fails | Branch protection | Add workflow to allowed actors |
| Helm errors | Chart version not found | Verify version exists upstream |

### Debug Commands

```bash
# Test version file format locally
grep -E '^(CILIUM\|TETRAGON)_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' versions

# Check available Helm versions
helm search repo cilium/cilium --versions
helm search repo cilium/tetragon --versions

# Manually generate template
source versions
helm template cilium cilium/cilium --version ${CILIUM_VERSION} -n kube-system
```

## 📚 Additional Resources

- [Workflows README](.github/workflows/README.md) - Detailed workflow documentation
- [Contributing Guide](../CONTRIBUTING.md) - How to contribute
- [Cilium Documentation](https://docs.cilium.io/) - Cilium official docs
- [Tetragon Documentation](https://tetragon.io/) - Tetragon official docs
- [Talos Linux](https://www.talos.dev/) - Talos documentation

## 🔐 Security Considerations

- **PAT Token:** Store securely, rotate regularly, use minimal scopes
- **Review PRs:** Always review auto-generated PRs before merging
- **Release Notes:** Check upstream release notes for security fixes
- **Version Pinning:** Keep versions pinned for production stability
- **Template Review:** Audit generated templates before deployment

## 🎓 Learning More

### Understanding the Workflows

Each workflow file is well-commented and follows GitHub Actions best practices:

- `update-versions.yml` - Version detection and PR creation
- `cilium-helm.yml` - Helm template generation with multiple variants
- `tetragon-helm.yml` - Tetragon-specific template generation

### Customizing Workflows

You can customize:

- Schedule timing (cron expression)
- Helm chart values
- Template variants
- Commit messages
- PR labels and descriptions

See the [workflows README](.github/workflows/README.md) for detailed customization options.

---

**Last Updated:** 2025-10-24

For questions or issues, please open a GitHub issue or check the workflow logs in the Actions tab.
