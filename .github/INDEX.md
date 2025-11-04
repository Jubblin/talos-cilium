# Documentation Index

Complete guide to all documentation in this repository.

## 📚 Quick Navigation

### Getting Started

1. **[Main README](../README.md)** - Start here! Overview of the repository
2. **[Automation Overview](AUTOMATION.md)** - Visual guide to automated workflows
3. **[Contributing Guide](../CONTRIBUTING.md)** - How to contribute to this project

### Automation & Workflows

- **[Workflows README](workflows/README.md)** (331 lines) - Complete workflow documentation
  - Update Versions Workflow - Auto-detect and update Cilium/Tetragon
  - Cilium Helm Generator - Generate Cilium templates
  - Tetragon Helm Generator - Generate Tetragon templates
  - Setup instructions, troubleshooting, and integration guide

### Development

- **[Git Hooks README](../.githooks/README.md)** (146 lines) - Container-based pre-commit hooks
  - Installation and setup
  - What gets checked
  - Troubleshooting guide

### Configuration

- **[Pre-commit Config](../.pre-commit-config.yaml)** - Pre-commit hooks configuration
- **[Makefile](../Makefile)** - Convenience commands
- **[Versions file](../versions)** - Version tracking

## 📖 Documentation by Topic

### Automation

| Document | Lines | Description |
|----------|-------|-------------|
| [AUTOMATION.md](AUTOMATION.md) | 258 | Visual flow and automation overview |
| [workflows/README.md](workflows/README.md) | 331 | Detailed workflow documentation |

### Development Guides

| Document | Lines | Description |
|----------|-------|-------------|
| [CONTRIBUTING.md](../CONTRIBUTING.md) | 203 | Contributor guide with pre-commit info |
| [.githooks/README.md](../.githooks/README.md) | 146 | Git hooks documentation |

### General

| Document | Lines | Description |
|----------|-------|-------------|
| [README.md](../README.md) | 73 | Main repository documentation |

**Total Documentation:** 1,011 lines across 5 main documents

## 🎯 Common Tasks

### I want to

#### Understand the automation

→ Read [AUTOMATION.md](AUTOMATION.md)

#### Set up version auto-updates

→ Follow [workflows/README.md#setup-instructions](workflows/README.md#setup-instructions)

#### Install pre-commit hooks

→ Run `make install-hooks` or read [.githooks/README.md](../.githooks/README.md)

#### Lint markdown files

→ Run `make lint-markdown`

#### Contribute to the project

→ Read [CONTRIBUTING.md](../CONTRIBUTING.md)

#### Understand a specific workflow

→ Check [workflows/README.md](workflows/README.md) sections:

- Update Versions Workflow (lines 15-88)
- Cilium Helm Generator (lines 91-178)
- Tetragon Helm Generator (lines 181-272)

#### Troubleshoot workflow issues

→ See [workflows/README.md#troubleshooting](workflows/README.md#troubleshooting)

#### Customize pre-commit checks

→ Edit [.pre-commit-config.yaml](../.pre-commit-config.yaml)

#### Update versions manually

→ Edit [versions](../versions) file, commit, and push

## 🔍 Documentation Features

### Workflow Documentation ([workflows/README.md](workflows/README.md))

- ✅ Complete overview table
- ✅ Detailed setup instructions
- ✅ PAT token setup guide (classic and fine-grained)
- ✅ Manual execution instructions
- ✅ Troubleshooting sections
- ✅ Mermaid diagrams for workflows
- ✅ Integration guide
- ✅ Best practices
- ✅ Environment variables reference

### Automation Overview ([AUTOMATION.md](AUTOMATION.md))

- ✅ Visual ASCII flow diagram
- ✅ Workflows summary table
- ✅ Benefits and features
- ✅ Setup requirements
- ✅ Monitoring commands
- ✅ Troubleshooting table
- ✅ Security considerations
- ✅ Debug commands

### Git Hooks Documentation ([.githooks/README.md](../.githooks/README.md))

- ✅ Installation instructions
- ✅ What gets checked
- ✅ Usage examples
- ✅ Container-based execution
- ✅ Troubleshooting guide
- ✅ File descriptions

### Contributing Guide ([CONTRIBUTING.md](../CONTRIBUTING.md))

- ✅ Prerequisites and setup
- ✅ Commit message conventions
- ✅ Testing instructions
- ✅ Project structure
- ✅ Troubleshooting
- ✅ Pull request process

## 📊 Documentation Statistics

```text
Total Documentation Files: 5 main documents
Total Lines: 1,011 lines
Average Document Size: 202 lines

Breakdown:
- Workflows README:     331 lines (33%)
- Automation Overview:  258 lines (26%)
- Contributing Guide:   203 lines (20%)
- Git Hooks README:     146 lines (14%)
- Main README:           73 lines (7%)
```

## 🎓 Learning Path

### For New Contributors

1. Read [README.md](../README.md) - Understand the project
2. Read [CONTRIBUTING.md](../CONTRIBUTING.md) - Learn how to contribute
3. Run `make install-hooks` - Set up development environment
4. Make changes and commit - Pre-commit runs automatically

### For Understanding Automation

1. Read [AUTOMATION.md](AUTOMATION.md) - See the big picture
2. Read [workflows/README.md](workflows/README.md) - Understand details
3. Set up PAT_TOKEN - Enable auto-updates
4. Watch the workflows run - Learn by observing

### For Maintainers

1. Review all documentation in order
2. Set up PAT_TOKEN for auto-updates
3. Configure repository variables for Helm generators
4. Monitor workflow runs regularly
5. Review and merge auto-generated PRs

## 🔗 External Resources

- [Cilium Documentation](https://docs.cilium.io/)
- [Tetragon Documentation](https://tetragon.io/)
- [Talos Linux Documentation](https://www.talos.dev/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Pre-commit Framework](https://pre-commit.com/)
- [Helm Documentation](https://helm.sh/docs/)

## 📝 Documentation Maintenance

### Updating Documentation

When updating workflows or adding features:

1. Update the relevant documentation file
2. Update this index if adding new documents
3. Update the main README if adding major features
4. Keep documentation in sync with code

### Documentation Standards

- Use clear, concise language
- Include examples where helpful
- Add troubleshooting sections
- Link to related documentation
- Keep table of contents updated
- Use consistent formatting

## 🆘 Getting Help

### Documentation Issues

If documentation is unclear or incorrect:

1. Open an issue describing the problem
2. Suggest improvements or clarifications
3. Submit a PR with documentation fixes

### Technical Issues

For technical problems:

1. Check the relevant troubleshooting section
2. Review workflow logs in the Actions tab
3. Open an issue with details and logs
4. Tag with appropriate labels

---

**Last Updated:** 2025-10-24

This index covers all major documentation. For the most up-to-date information, always refer to the linked documents.
