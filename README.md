# talos-cilium

Talos/Omni patches that bring up a cluster with Cilium (kube-proxy replacement)
as the only CNI. Cilium and Flux are installed by in-cluster Helm Jobs, defined
as kustomize bundles and inlined into the Talos config as `inlineManifests`.

## Inventory

All patches are in [`patches/`](./patches):

* [Raspberry Pi 3-node cluster](./patches/pinode.yaml) — Cilium + Flux Operator + FluxInstance bootstrap (rendered, see below)
* [Schedule on control planes](./patches/allowSchedulingOnControlPlanes.yaml)
* Node examples: [e1000e](./patches/e1000e.yaml), [GPU worker](./patches/gpu-worker-patch.yaml), [machine-specific](./patches/machine-patch.yaml)

Bootstrap sources: [`cilium/`](./cilium) and [`flux-operator/`](./flux-operator).

## Cilium version

`cilium/jobs/job.yaml` and `patches/pinode.yaml` pin the Helm chart (currently
**1.20.5**). The daily `update-versions.yml` workflow opens a PR that bumps the
`versions` file and both pins. Before merging, check the new Cilium release
supports your Talos/Kubernetes versions. The `alpine/k8s` image tag is only the
kubectl/helm client; keep it on the cluster's Kubernetes minor version.

### Compatibility check for 1.20.5

* Target: Talos 1.14.6, Kubernetes 1.36.x, Cilium 1.20.5. Cilium 1.20 supports Kubernetes 1.33–1.36, so 1.36 is the
  newest supported version ([compatibility table][k8s]). Kubernetes 1.37 is not supported by any stable Cilium yet.
* Talos: Cilium requires Talos 1.5.0 or later and kernel 5.10 or later ([install guide][helm]).
  The values in `cilium/values.yaml` match the [Talos Cilium guide][talos] for kube-proxy-free mode.
* Talos 1.14 deprecates `cluster.inlineManifests`, `cluster.proxy` and `cluster.network` in favour of the
  `KubeInlineManifestConfig`, `KubeProxyConfig` and `KubeFlannelCNIConfig` documents. This repo keeps the old keys:
  they are deprecated, not removed, and they also work on Talos 1.13 and earlier. Not yet confirmed on a live 1.14.6
  cluster; migrate if the first run rejects them.
* Helm values: none of the keys in `cilium/values.yaml` are in the [1.20 removed or renamed list][upgrade].
* Job client: `alpine/k8s:1.36.6` matches the cluster's Kubernetes minor. Keep the tag on the cluster's minor version.

[k8s]: https://docs.cilium.io/en/v1.20/network/kubernetes/compatibility/
[helm]: https://docs.cilium.io/en/v1.20/installation/k8s-install-helm/
[talos]: https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium
[upgrade]: https://docs.cilium.io/en/v1.20/operations/upgrade/

## Re-rendering pinode.yaml

`patches/pinode.yaml` holds rendered copies of the two kustomize bundles. Never
edit them by hand. After changing `cilium/` or `flux-operator/`, run:

```bash
make render-pinode   # kubectl kustomize + yq
```

## Flux / SOPS bootstrap (manual prerequisites)

The Flux instance syncs `Jubblin/stormcraft` using a `git` Secret that a Job
decrypts from `flux-operator/git-secret.enc.yaml`. That file is a **placeholder**.
The owner must create an age key, store it as the `flux-system/sops-age` Secret,
and commit the sops-encrypted secret (steps are in the file header). The decrypt
Job runs `apk add sops age` unpinned at runtime (accepted risk).

## Control-plane count

The Cilium preflight no longer expects a fixed number of control planes. It waits up to
15 minutes for the API, at least one control-plane node, and a node count unchanged for
60 seconds, then installs. Trade-off: a cluster that comes up with fewer control planes
than intended is not rejected, so check the node count in Omni.

## Cleanup after bootstrap

The installers run as cluster-admin. Once Cilium and Flux are healthy, remove them:

```bash
kubectl delete clusterrolebinding cilium-installer flux-operator-installer
```

## Deferred

Removed with the old template-URL patches (still in git history) and not yet
ported to the Helm-Job approach: Tetragon, metrics-server,
kubelet-serving-cert-approver, the Cilium Prometheus monitoring example, and
the PodSecurity admission config from `cluster.yaml`.
