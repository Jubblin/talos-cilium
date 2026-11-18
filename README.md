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
kubectl/helm client; keep it within kubectl version skew of the cluster.

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

## Single-node or other control-plane counts

The Cilium preflight expects 3 control-plane nodes. Change
`EXPECTED_CONTROL_PLANE_COUNT` in `cilium/jobs/job.yaml` for other sizes, then re-render.

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
