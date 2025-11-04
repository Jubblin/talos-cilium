# GitHub Actions Workflows

## build-precommit-image.yml

This workflow automatically builds, secures, and publishes the pre-commit container image to GitHub Container Registry (GHCR).

### Triggers

- **Push to main**: When `Dockerfile.precommit` or the workflow file is updated on the main branch
- **Pull Request**: Builds (but doesn't push) the image for testing when the Dockerfile or workflow is modified
- **Manual**: Can be triggered manually via workflow_dispatch

### What It Does

The workflow follows a **security-first** approach:

1. **Build Locally**: Builds a single-arch image locally for scanning
   - Uses build cache for efficiency
   - Exports image to Docker for scanning

2. **Security Scanning** (BEFORE pushing):
   - **Trivy**: Scans for CRITICAL and HIGH vulnerabilities
   - **Exit on failure**: If vulnerabilities are found, the workflow stops
   - Results uploaded to GitHub Security tab (SARIF format)
   - Console output for immediate visibility

3. **Build and Push Multi-Architecture** (ONLY if Trivy passes):
   - Builds for both `linux/amd64` and `linux/arm64` platforms
   - Creates multiple tags:
     - `latest` - for main branch builds
     - `main-<sha>` - commit SHA tagged images
     - `pr-<number>` - for pull request builds (not pushed)

4. **SBOM Generation**: Creates Software Bill of Materials in SPDX format
   - Only runs after successful push
   - Uploaded as workflow artifact
   - Useful for supply chain security and compliance

5. **Image Signing**: Signs container images using Cosign with keyless signing
   - Only runs after successful push
   - Uses GitHub's OIDC token for attestation
   - Verifiable with `cosign verify`

### Permissions Required

The workflow requires the following permissions:

- `contents: read` - Read repository contents
- `packages: write` - Push to GHCR
- `id-token: write` - OIDC token for cosign signing
- `security-events: write` - Upload security scan results

### Using the Published Image

Pull the latest image:

```bash
docker pull ghcr.io/$(git remote get-url origin | sed 's/.*:\(.*\)\.git/\1/' | tr '[:upper:]' '[:lower:]')/pre-commit:latest
```

Or reference it in your pre-commit hooks or Makefile.

### Verifying Image Signatures

Verify the image signature with cosign:

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/.*/.github/workflows/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/YOUR-ORG/YOUR-REPO/pre-commit:latest
```

### Viewing Security Scan Results

1. Go to the **Security** tab in your repository
2. Click on **Code scanning alerts**
3. View Trivy scan results for the container image

### Artifacts

Each successful build produces:

- **SBOM**: `sbom-precommit.spdx.json` - Software Bill of Materials
- **Trivy Results**: Available in GitHub Security tab

### Security Gates

The workflow implements a **gate system** to ensure only secure images are published:

- ✅ **Trivy Scan Gate**: Images with CRITICAL or HIGH vulnerabilities will NOT be pushed to GHCR
- ✅ **Always Upload Results**: Security scan results are uploaded to GitHub Security tab even on failure
- ✅ **PR Protection**: Pull requests build and scan but never push images

### Best Practices

1. **Review PR Builds**: The workflow builds and scans (but doesn't push) images on PRs to catch issues early
2. **Monitor Security Alerts**: Check the Security tab regularly for vulnerability reports
3. **Update Base Images**: Keep the Python base image and yamlfmt versions up to date to pass security scans
4. **Review SBOM**: Use the SBOM artifact for compliance and security auditing
5. **Fix Vulnerabilities**: If a build fails Trivy scan, update dependencies or base images before the image is published
