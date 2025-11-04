# Pre-commit Docker Image

This Dockerfile builds a custom container image with all tools needed to run the pre-commit hooks for this repository.

## What's Included

The image is based on `python:3.14-slim` and includes:

- **pre-commit** - The pre-commit framework
- **yamlfmt** - YAML formatting tool (v0.20.0, copied from official image)
- **Git** - Required for pre-commit operations

## Getting the Image

### From GitHub Container Registry (Recommended)

The image is automatically built and published to GHCR when the Dockerfile is updated:

```bash
docker pull ghcr.io/OWNER/REPO/pre-commit:latest
```

The published image includes:

- Multi-architecture support (amd64, arm64)
- **Pre-publication security scanning**: Images are scanned with Trivy BEFORE being pushed to GHCR
- **Security gate**: Only images passing vulnerability scans (no CRITICAL/HIGH) are published
- SBOM (Software Bill of Materials)
- Signed with Cosign for supply chain security

### Building Locally

#### Using Make

```bash
make build-precommit-image
```

#### Using the Build Script

```bash
./.githooks/build-precommit-image.sh
```

#### Manual Build

```bash
docker build -f Dockerfile.precommit -t talos-cilium/pre-commit:latest .
```

## Using the Image

### With the Git Hooks

The image is automatically used by the git pre-commit hook:

```bash
# After building the image, install hooks
make install-hooks

# Now commits will automatically use the image
git commit -m "your message"
```

### Manual Execution

Run all checks:

```bash
docker run --rm -v "$(pwd):/src" -w /src talos-cilium/pre-commit:latest run --all-files
```

Run specific hook:

```bash
docker run --rm -v "$(pwd):/src" -w /src talos-cilium/pre-commit:latest run check-yaml
```

Run checks on staged files only:

```bash
docker run --rm -v "$(pwd):/src" -w /src talos-cilium/pre-commit:latest run
```

## Image Details

- **Registry**: `ghcr.io/OWNER/REPO/pre-commit`
- **Local Name**: `talos-cilium/pre-commit`
- **Tags**: `latest`, `main-<sha>`
- **Platforms**: `linux/amd64`, `linux/arm64`
- **Base Image**: `python:3.14-slim`
- **Maintainer**: `Jubblin`
- **Entrypoint**: `pre-commit`
- **Default Command**: `run --all-files`

## Security Features

The published container image includes several security measures:

### Vulnerability Scanning

Every image is scanned with Trivy for vulnerabilities **before publication**:

- **Security gate**: Images with CRITICAL or HIGH vulnerabilities are blocked from publishing
- Results are posted to GitHub Security tab for review
- Scans include CRITICAL, HIGH, and MEDIUM severity issues
- Automated on every build
- Only secure images reach GHCR

### Image Signing

Images are signed using Cosign with keyless signing:

```bash
# Verify image signature
cosign verify \
  --certificate-identity-regexp="https://github.com/.*/.github/workflows/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/OWNER/REPO/pre-commit:latest
```

### Software Bill of Materials (SBOM)

Each build generates an SBOM in SPDX format, available as a workflow artifact for:

- Supply chain security auditing
- Compliance requirements
- Dependency tracking

## Updating Tools

To update versions of included tools:

1. Edit `Dockerfile.precommit`
2. Update the yamlfmt version by changing the tag in the `FROM ghcr.io/google/yamlfmt` line
3. Commit and push to main - the GitHub Actions workflow will automatically:
   - Build the new image for both amd64 and arm64
   - Scan for vulnerabilities
   - Generate SBOM
   - Sign the image
   - Push to GHCR

For local development/testing, rebuild with: `make build-precommit-image`

## Troubleshooting

### Image Not Found

If you see "Docker image 'talos-cilium/pre-commit:latest' not found":

```bash
make build-precommit-image
```

### Permission Issues

If you encounter permission errors, the image runs as your user ID by default. Check that Docker is properly configured.

### Tool Version Mismatches

If hooks fail after updating `.pre-commit-config.yaml`, rebuild the image to ensure tool versions match:

```bash
make build-precommit-image
```
