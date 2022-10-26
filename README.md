# OpenShift 4 on Exoscale

> :warning: **WIP**: This is still a work in progress and will change!

This repository provides a Terraform module to provision the infrastructure for an OpenShift 4 cluster on Exoscale.

Please see the [VSHN OCP4 on Exoscale install how-to](https://openshift.docs.vshn.ch/oc4/how-tos/exoscale/install.html) for a step-by-step installation guide.

## Overview

The Terraform module in this repository provisions all the infrastructure which is required to setup an OpenShift 4 cluster on Exoscale using UPI (User-provisioned infrastructure).

The module manages the VMs (including their Ignition or cloud-init config), DNS zone and records, security groups, and floating IPs for a highly-available OpenShift 4 cluster.

By default, the module will provision all the VMs with public IPs (the default on Exoscale), and restricts access to the cluster VMs using Exoscale's security group mechanism.
Out of the box, all the cluster VMs (which use RedHat CoreOS) are reachable over SSH for debugging purposes using a SSH key which is provided during provisioning.

The module expects that a suitable RHCOS VM template is available in the Exoscale organisation and region in which the cluster is getting deployed.

The module also provisions a pair of load balancer VMs.
The module uses [vshn-lbaas-exoscale](https://github.com/appuio/terraform-modules/tree/main/modules/vshn-lbaas-exoscale) to provision the LBs.

### Module input variables

The module provides variables to

* control the instance size of each VM type (LB, bootstrap, master, infra, storage, and worker).
  Note that we don't officially support smaller instance sizes than the ones provided as defaults.
* control the count of each VM type (LB, bootstrap, master, infra, storage, and worker).
  Note that we don't recommend changing the count for the LBs and masters from their default values.
* control the size of the root partition for all nodes.
  This value is used for all nodes and cannot be customized for individual node groups.
* control the size of the empty partition on worker or infra nodes.
  By default, worker and infra nodes are provisioned without an empty partition (by defaulting the variable to 0)
  However, users can create worker and infra nodes with an empty partition by providing a positive value for the variable.
* control the size of the empty partition on the storage nodes.
  This partition can be used as backing storage by in-cluster storage clusters, such as Rook-Ceph.
* configure additional worker node groups.
  This variable is a map from worker group names (used as node prefixes) to objects providing node instance size, node count, node data disk size, and node state.
* configure additional affinity group IDs which are configured on all master, infra, storage, and worker VMs
  This allows users to configure pre-existing affinity groups (e.g. for Exoscale dedicated VM hosts) for the cluster
* configure additional security group IDs which are configured on worker VMs
  This allows users to configure pre-existing security groups (e.g. for node ports) for the worker nodes
* specify the cluster's id, name (optional), Exoscale region, base domain, SSH key, RHCOS template, and Ignition API CA.
* enable PROXY protocol on the LBs for the ingress router.
* configure additional Exoscale private networks to attach to the LBs.
  To avoid issues with network interfaces getting assigned arbitrarily, we recommend to only configure additional private networks after the LBs have been provisioned.
* specify a bootstrap S3 bucket (required only to provision the boostrap node)
* specify the username for the APPUiO hieradata Git repository (see next sections for details).
* provide an API token for control.vshn.net (see next sections for details).
* choose a dedicated deployment target
  This allows for using dedicated hypervisors.

The cluster's domain is constructed from the provided base domain, cluster id and cluster name.
If a cluster name is provided the cluster domain is set to `<cluster name>.<base domain>`.
Otherwise the cluster domain is set to `<cluster id>.<base domain>`.

## Configuring additional worker groups

Please note that you cannot use names "master", "infra", "worker" or "storage" for additional worker groups.
We prohibit these names to ensure there are no collisions between the generated nodes names for different worker groups.

As the examples show, attributes `disk_size`, `state` and `affinity_group_ids` for entries in `additional_worker_groups` are optional.
If these attributes are not given, the nodes are deployed with `disk_size = var.root_disk_size`, `state = "Running"` and `affinity_group_ids = []`.

To configure an additional worker group named "cpu1" with 3 instances with type "CPU-huge" the following input can be given:

```terraform
# File main.tf
module "cluster" {
  // Remaining config for module omitted

  additional_worker_groups = {
    "cpu1": {
      size: "CPU-huge"
      count: 3
    }
  }
}
```

To configure an additional worker group named "storage1" with 3 instances with type "Storage-huge", and 5120GB of total disk size (120GB root disk + 5000GB data disk), the following input can be given:

```terraform
# File main.tf
module "cluster" {
  // Remaining config for module omitted

  additional_worker_groups = {
    "storage1": {
      size: "Storage-huge"
      count: 3
      data_disk_size: 5000
    }
  }
}
```

## Required credentials

* An unrestricted Exoscale API key in the organisation in which the cluster should be deployed
* An API token for the Servers API must be created on [control.vshn.net](https://control.vshn.net/tokens/_create/servers)
* A project access token for the APPUiO hieradata repository must be created on [git.vshn.net](https://git.vshn.net/appuio/appuio_hieradata/-/settings/access_tokens)
  * The minimum required permissions for the project access token are `api` (to create MRs), `read_repository` (to clone the repo) and `write_repository` (to push to the repo).

## VSHN service dependencies

Since the module manages a VSHN-specific Puppet configuration for the LB VMs, it needs access to some https://www.vshn.ch[VSHN] infrastructure:

* The module makes requests to the control.vshn.net [Servers API](https://control.docs.vshn.ch/control/api_servers.html) to register the LB VMs in VSHN's Puppet enc (external node classifier)
* The module needs access to the [APPUiO hieradata on git.vshn.net](https://git.vshn.net/appuio/appuio_hieradata) to create the appropriate configuration for the LBs

### Using the module outside VSHN

If you're interested in a version of the module which doesn't include VSHN-managed LBs, you can check out the standalone MVP LB configuration in commit [172e2a0](https://github.com/appuio/terraform-openshift4-exoscale/commit/172e2a074b6b23e995ba961da0688397a10474bb).

> :warning: Please note that we're not actively developing the MVP LB configuration at the moment.

## Optional features

### Private network

> :warning: This mode is less polished than the default mode and we're currently not actively working on improving this mode.

Optionally, the OpenShift 4 cluster VMs can be provisioned solely in an Exoscale managed private network.
To use this variation, set module variable `use_privnet` to `true`.
If required, you can change the CIDR of the private network by setting variable `privnet_cidr`.

When deploying the RHCOS VMs with a private network only, the VMs **must** first be provisioned in `Stopped` state, and then powered on in a subsequent apply step.
Otherwise, the initial Ignition config run fails because the Ignition API is not reachable early enough in the boot process, as the network interface is also configured by Ignition in this scenario.
This can be achieved by running the following sequence of `terraform apply` steps.
The example assumes that the LBs and bootstrap node have been provisioned correctly already and that we're now provisioning the OCP4 master VMs.

```bash
for state in "stopped" "running" "running"; do
  cat >override.tf <<EOF
  module "cluster" {
    bootstrap_count = 1
    infra_count = 0
    worker_count = 0
    master_state = "${state}"
  }
  terraform apply
done
```

Note: the second `terraform apply` with `state = "Running"` may not be required in all cases, but is there as a safeguard if creation of DNS records fails in the first `terraform apply` with `state = "Running".
