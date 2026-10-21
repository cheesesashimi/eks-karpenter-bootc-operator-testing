# EKS Karpenter / bootc-operator Test Environment

This repository creates an Amazon EKS cluster with:

- A custom AMI managed node group.
- [Karpenter](https://karpenter.sh) and its interruption handling resources.
- [bootc-operator](https://github.com/bootc-dev/bootc-operator) and `BootcNodePool`
- Public and private VPC subnets, NAT gateways, and a discovery-tagged node
  security group.

The EKS infrastructure and Kubernetes resources are managed as separate
OpenTofu stacks in `eks/` and `addons/`. Apply and destroy them in the order
described below.

Generally speaking, these configs are more or less a reimplementation of the
[Getting Started With
Karpenter](https://karpenter.sh/docs/getting-started/getting-started-with-karpenter/)
instructions using OpenTofu. The reason for this is because `eksctl` uses AWS
CloudFormation stacks which can sometimes be tricky to teardown. By using
OpenTofu to perform the same function as CloudFormation, tighter control over
the teardown process can be achieved. However, this is done at the expense of
requiring more granular and verbose configs.

In the interest of full disclosure: Almost all of the code in this repository
is AI-generated for the specific purpose of testing the interaction between
bootc-operator and Karpenter in an EKS environment.

## Prerequisites

- OpenTofu `>= 1.6.0`.
- AWS CLI configured for the target account.
- AWS credentials able to create EKS, EC2/VPC, IAM, SQS, EventBridge, and
  CloudWatch resources.
- `kubectl`, Helm, and an AWS CLI credential plugin available locally.
- A local checkout of the bootc-operator repository for access to its Helm chart.
- A region-compatible, EKS-compatible custom AMI.

A [Toolbox](https://github.com/containers/toolbox/) container image containing
these tools can be pulled from
`quay.io/zzlotnik/toolbox:cloud-cli-aws-fedora-44`.

The AMI must support the AL2023 `node.eks.aws/v1alpha1` bootstrap
configuration. The managed node group uses `ami_type = "CUSTOM"`, while the
launch template provides the bootstrap data explicitly. Karpenter uses the same
AMI as an `AL2023` AMI family. The infrastructure stack also discovers the
bootc OS image from the initial node and exports it for the addon stack; set
`bootc_os_image` explicitly when that discovery is not available or a different
bootc OS image is desired.

## Configuration

See [CONFIGURATION.md](CONFIGURATION.md) for the variable reference, `tfvars`
file setup, and configuration overrides.

## Create Infrastructure

Run these commands from the repository root:

```bash
tofu -chdir=eks init
tofu -chdir=eks plan
tofu -chdir=eks apply
```

The infrastructure stack creates the VPC, subnets, NAT gateways, EKS control
plane, managed node group, IAM roles, Karpenter interruption queue, and AWS
EKS access resources.

After the infrastructure is ready, the apply also runs `aws eks
update-kubeconfig` and writes the kubeconfig to the configured location.

The node group uses a custom security group in its launch template. The
configuration explicitly allows traffic from the node security group to the
EKS API server security group on TCP port 443, as well as control-plane traffic
to the node kubelets on TCP port 10250. These rules are required because EKS
does not automatically attach the cluster security group to instances when a
custom security group is specified in the launch template.

### Refresh the Kubeconfig Manually

If AWS credentials expire or the kubeconfig needs to be refreshed, renew the
AWS credentials and run:

```bash
aws eks update-kubeconfig \
  --region "$(tofu -chdir=eks output -raw aws_region)" \
  --name "$(tofu -chdir=eks output -raw cluster_name)" \
  --kubeconfig "$(tofu -chdir=eks output -raw kubeconfig_path)"
```

Verify that the renewed credentials are active with `aws sts
get-caller-identity` before running the command.

Wait for the cluster and managed node group to become ready before applying
the addon stack:

```bash
aws eks describe-cluster \
  --name "$(tofu -chdir=eks output -raw cluster_name)" \
  --query 'cluster.status'

aws eks list-nodegroups \
  --cluster-name "$(tofu -chdir=eks output -raw cluster_name)"
```

The managed node group IAM role is authorized automatically by EKS as part of
managed node group creation. The infrastructure stack creates an explicit
`EC2_LINUX` access entry only for the Karpenter node role.

Use the AWS CLI as the source of truth for node group status and health:

```bash
aws eks describe-nodegroup \
  --cluster-name "$(tofu -chdir=eks output -raw cluster_name)" \
  --nodegroup-name "$(tofu -chdir=eks output -raw cluster_name)-ng" \
  --query 'nodegroup.{status:status,issues:health.issues}'
```

The console can continue to display a historical `Create failed` message
after a failed instance is replaced and the node group becomes `ACTIVE`. If
the CLI reports `ACTIVE`, health issues are empty, and `kubectl get nodes`
shows a `Ready` node, the node group is functioning. Verify the AWS account
and region in the console before treating the historical message as current.

## Install Cluster Addons

The addon stack reads the infrastructure outputs from the local state file
`eks/terraform.tfstate` by default:

```bash
tofu -chdir=addons init
tofu -chdir=addons plan
tofu -chdir=addons apply
```

Initialize and apply the infrastructure stack first so this state file exists.
For shared or remote use, configure `infrastructure_state_path` and both stacks'
backend settings consistently; the repository does not provide an account-
specific remote backend.

### Addon Authentication

The addon providers do not read the generated `kubeconfig` directly. They use
the cluster endpoint and CA certificate from the infrastructure state, then
invoke the AWS CLI exec plugin:

```text
aws eks get-token --cluster-name <cluster-name>
```

The AWS CLI uses the active AWS credential chain, such as environment
credentials, a configured profile or SSO session, or an assumed role. EKS
validates the resulting short-lived token and authorizes the IAM principal
through EKS access entries and Kubernetes RBAC. Check the identity that will
be used by the addon stack with:

```bash
aws sts get-caller-identity
```

The identity must be the cluster creator or have an appropriate EKS access
entry and Kubernetes permissions. Refresh expired AWS credentials before
running the addon stack.

This installs Karpenter and the bootc-operator, then creates:

- `EC2NodeClass/default`
- `NodePool/default`
- `BootcNodePool/karpenter`
- `BootcNodePool/default`

The addon stack also creates the `inflate` deployment with zero replicas. It is
available as a small workload that can be scaled up when testing Karpenter
provisioning and consolidation.

Verify the cluster:

```bash
kubectl get nodes
kubectl get nodepool,ec2nodeclass -A
kubectl get bootcnodepool -A
kubectl -n kube-system get pods -l app.kubernetes.io/name=karpenter
```

## Tear Down

Destroy the addon stack first so Karpenter and the bootc-operator can remove
their Kubernetes-managed nodes:

```bash
tofu -chdir=addons destroy
```

Before destroying infrastructure, check for remaining external resources:

```bash
kubectl get nodes
kubectl get nodeclaims -A
kubectl get svc -A
kubectl get ingress -A
```

If any load balancers or Karpenter nodes remain, remove them and wait for the
corresponding EC2 instances, ENIs, and load balancers to disappear.

Then destroy the infrastructure stack:

```bash
tofu -chdir=eks destroy
```

The intended teardown order is:

1. Kubernetes node pools and node classes.
2. Helm releases.
3. Managed node group.
4. EKS cluster.
5. NAT gateways and private routing.
6. Internet gateway and public networking.
7. VPC and IAM resources.

Do not manually delete EKS requester-managed ENIs while the cluster or node
group is still being deleted.
