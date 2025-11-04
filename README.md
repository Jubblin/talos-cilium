# talos-cilium README.md

## TLDR

Repo with generated helm templates to help deploy talos via omni patches. Templates are automatically generated and organized by component and version in the `/templates` directory

## Inventory

All patches reference templates from the versioned `/templates` directory structure.

### Talos Patches

All patches use `latest` symlinks that automatically point to the current versions (Cilium 1.17.6, Tetragon 1.4.1).

| Patch | Cilium Template | Tetragon Template | Description |
|-------|----------------|-------------------|-------------|
| [cluster-patch.yaml](./cluster-patch.yaml) | `cilium/latest/cilium.yaml` | `tetragon/latest/tetragon.yaml` | Standard multi-node cluster |
| [cluster with no workers.yml](./cluster%20with%20no%20workers.yml) | `cilium/latest/cilium.yaml` | `tetragon/latest/tetragon.yaml` | Control-plane only cluster |
| [single-node.yaml](./single-node.yaml) | `cilium/latest/cilium-single-node.yaml` | `tetragon/latest/tetragon-single-node.yaml` | Single node cluster |
| [pinode.yaml](./pinode.yaml) | `cilium/latest/cilium-single-node.yaml` | `tetragon/latest/tetragon-single-node.yaml` | Raspberry Pi single node |
| [allowSchedulingOnControlPlanes.yaml](./allowSchedulingOnControlPlanes.yaml) | N/A | N/A | Simple scheduling config only |

**Benefits of using `latest` symlinks:**

- 🔄 Automatic updates when new versions are released
- 🎯 Patches always reference current stable versions
- 📌 Specific versions remain available under versioned directories
- 🔙 Easy rollback by changing symlink if needed

All patches (except `allowSchedulingOnControlPlanes.yaml`) also include:

- Kubelet Serving Cert Approver
- Metrics Server
- Prometheus monitoring
- Flux Operator

## Automation

This repository uses GitHub Actions workflows to automate version management and Helm template generation.

### Workflows

* **[Version Updater](./.github/workflows/update-versions.yml)** - Daily checks for new releases, creates PRs
* **[Cilium Helm Generator](./.github/workflows/cilium-helm.yml)** - Generates Cilium templates
* **[Tetragon Helm Generator](./.github/workflows/tetragon-helm.yml)** - Generates Tetragon templates

### Generated Templates Structure

Templates are organized in versioned directories with `latest` symlinks for easy reference:

```text
templates/
├── cilium/
│   ├── latest -> 1.17.6/
│   └── 1.17.6/
│       ├── cilium-secure.yaml
│       ├── cilium.yaml
│       └── cilium-single-node.yaml
└── tetragon/
    ├── latest -> 1.4.1/
    └── 1.4.1/
        ├── tetragon.yaml
        └── tetragon-single-node.yaml
```

**How it works:**

- Each version gets its own directory (e.g., `1.17.6/`)
- A `latest` symlink points to the current version
- Talos patches reference `latest/` for automatic updates
- Workflows update both templates and symlinks when versions change

This structure allows you to:

- 🔄 Automatic version updates via symlinks
- 📊 Track templates across different versions
- 🔍 Compare changes between versions
- 📚 Keep historical templates available
- 🎯 Pin to specific versions when needed

### Documentation

* 📖 **[Automation Overview](./.github/AUTOMATION.md)** - Visual flow and complete automation guide
* 📋 **[Workflows Documentation](./.github/workflows/README.md)** - Detailed setup and troubleshooting

**Quick Start:**

1. Set up `PAT_TOKEN` secret for auto-updates ([instructions](./.github/workflows/README.md#setup-instructions))
2. Workflows run automatically on version changes
3. Review and merge auto-generated PRs
4. Templates are generated in `/templates/{component}/{version}/`

## Development

### Git Hooks (Pre-commit)

This repository uses containerized pre-commit hooks to ensure code quality.

**Quick Start:**

```bash
# Install the git hooks
make install-hooks
# or
./.githooks/install.sh
```

**Requirements:**

* Docker (must be running)

**What gets checked:**

* YAML validation and formatting
* Markdown linting
* Shell script linting (shellcheck)
* Custom version file validation

**Usage:**

```bash
# Automatic - runs on every commit
git commit -m "your message"

# Manual - check all files
make pre-commit-all

# Manual - check staged files only
make pre-commit

# Lint markdown documentation
make lint-markdown
```

See [.githooks/README.md](./.githooks/README.md) for more details.
