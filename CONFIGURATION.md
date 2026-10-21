# Configuration

Infrastructure and addon variables are defined in their respective OpenTofu
stacks.

## Infrastructure Variables

Infrastructure variables are in `eks/variables.tf`:

- `aws_region`
- `cluster_name` (required)
- `kubeconfig_path`
- `node_group_desired_size`
- `node_group_instance_types`
- `karpenter_namespace`
- `k8s_version`
- `ami_id`

## Addon Variables

Addon variables are in `addons/variables.tf`:

- `karpenter_version`
- `karpenter_instance_types`
- `enable_zonal_shift`
- `bootc_operator_chart_path` (required)
- `bootc_operator_image_repo`
- `bootc_operator_image_tag`
- `bootc_os_image` (optional override)

## Variable Files

The local `eks/terraform.tfvars` and `addons/terraform.tfvars` files are loaded
automatically by their respective stacks and are ignored by Git. Create them
from the repository root, for example:

```bash
echo 'cluster_name = "my-eks-cluster"' > eks/terraform.tfvars
echo 'bootc_operator_chart_path = "/path/to/bootc-operator/chart/bootc-operator"' > addons/terraform.tfvars
```

For a custom variable filename, create the file and pass it explicitly:

```bash
echo 'cluster_name = "my-eks-cluster"' > myvars.tfvars
tofu -chdir=eks apply -var-file=../myvars.tfvars
```

Set `cluster_name` in the infrastructure file and
`bootc_operator_chart_path` in the addon file before applying. The addon stack
reads `karpenter_namespace` from the infrastructure stack output, so configure
that value only in `eks/terraform.tfvars` if you need to change it.

The addon stack also reads `infrastructure_state_path` from
`addons/providers.tf`. It defaults to `../eks/terraform.tfstate`, so the
infrastructure stack must be applied first. `bootc_os_image` defaults to the
image reference exported by the infrastructure stack and only needs to be set
when overriding that value.

Override other values with a variable file or `-var`, for example:

```bash
tofu -chdir=eks apply \
  -var='aws_region=us-east-1' \
  -var='cluster_name=my-bootc-cluster' \
  -var='ami_id=ami-0123456789abcdef0' \
  -var='node_group_desired_size=2' \
  -var='node_group_instance_types=["m5.large","m5.xlarge"]'
```

Pass additional addon variables to the command run with `-chdir=addons`.

For example:

```bash
tofu -chdir=addons apply \
  -var='karpenter_version=1.15.0' \
  -var='karpenter_instance_types=["t3.medium","m5.large"]' \
  -var='enable_zonal_shift=false'
```

The infrastructure apply writes the kubeconfig to `./kubeconfig` in the
repository root by default. Override the destination with
`-var='kubeconfig_path=/path/to/config'`.
