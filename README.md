# talos-cilium README.md

## TLDR

Repo with generated helm templates to help deploy talos via omni patches.
Templates are automatically generated and organized by component and version
in the `/templates` directory

## Inventory

All patches include Cilium, Tetragon, Prometheus and FluxOperator

* [Simple Patch to Schedule on Controlplanes](./allowSchedulingOnControlPlanes.yaml)
* [Single Node Patch](./single-node.yaml)
* [Raspberry Pi Node Patch](./pinode.yaml)
* [Cluster Patch](./cluster-patch.yaml)
* [Cluster Patch with no workers](./cluster%20with%20no%20workers.yml)

## Actions

How does it generate the helm templates?

* [Cilium Helm Template Generator](./.github/workflows/cilium-helm.yml)
* [Tetragon Helm Template Generator](./.github/workflows/tetragon-helm.yml)
