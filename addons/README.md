# Cluster Addons

This stack manages resources that require a reachable Kubernetes API. Apply the
`eks/` stack first, then initialize and apply this directory from the repository
root.

```bash
tofu -chdir=eks init
tofu -chdir=eks apply
tofu -chdir=addons init
tofu -chdir=addons apply
```

The official Kubernetes provider cannot manage the Karpenter and bootc-operator
custom resources here. Its `kubernetes_manifest` resource discovers the
resource schema from the Kubernetes API during planning. That happens before a
Helm release in the same apply can install the CRDs, so a new cluster fails at
plan time even when the custom resources have a `depends_on` relationship with
the Helm releases.

The stack therefore uses the `gavinbunney/kubectl` provider's
`kubectl_manifest` resources. They apply the manifests without requiring the
CRD schemas during planning, and their dependencies ensure that Helm installs
the CRDs before the corresponding custom resources are applied. This avoids a
separate targeted apply solely to bootstrap the CRDs.

Changing from `kubectl_manifest` to `kubernetes_manifest` (or vice versa)
changes the Terraform resource types. Review the plan carefully when upgrading
an existing addon state and preserve live resources through the normal
Terraform import/state migration process rather than accepting an unintended
destroy.

Destroy in the reverse order:

```bash
tofu -chdir=addons destroy
tofu -chdir=eks destroy
```

Before destroying the infrastructure stack, confirm that the addon stack has
removed its Kubernetes resources and that Karpenter-created nodes and load
balancers are gone.

Set `karpenter_instance_types` to control which EC2 instance types Karpenter
may provision. It defaults to `t3.medium`.

The local remote-state path is transitional. For shared use, configure both
stacks with the same encrypted remote backend before applying them.

The default local path is `../eks/terraform.tfstate`, controlled by
`infrastructure_state_path`. If the infrastructure state is stored elsewhere,
pass the matching path to every `tofu -chdir=addons` command, for example:

```bash
tofu -chdir=addons plan \
  -var='infrastructure_state_path=/path/to/eks/terraform.tfstate'
```

The infrastructure stack exports the bootc OS image discovered from the initial
node. Override it with `bootc_os_image` when the desired image differs.
