#!/bin/sh

# script that runs if the sandbox deprovison terraform destroy run fails
# attempts to delete any and all trailing resources related to the sandbox tf module, including:
#
#  - node groups
#  - cluster
#  - albs
#
# NOTE: this script is not concerned with destroying the VPC. That responsibility falls on the cloudformation stack.
# NOTE: the functionality here is predicated on the existence of a tag (install.nuon.co/id) on the resources.

set -u
set -o pipefail

# TODO: consider filtering by `sandbox.nuon.co/name = aws-eks` as well
TAG_KEY="install.nuon.co/id"
TAG_VALUE="${NUON_INSTALL_ID:-}"  # Defaults to env var
DRY_RUN="${DRY_RUN:-false}"  # Defaults to false if not set

# Usage function
usage() {
    echo "Usage: NUON_INSTALL_ID=<value> $0"
    echo "Set DRY_RUN=true in the environment for dry-run mode."
    exit 1
}

if [ -z "$TAG_VALUE" ]; then
    echo "Error: NUON_INSTALL_ID is required."
    usage
fi

# Determine dry-run behavior
if [ "$DRY_RUN" = "true" ]; then
    echo "Running in DRY-RUN mode. No resources will be deleted."
    RUN_CMD_PREFIX="echo [DRY-RUN]"
else
    RUN_CMD_PREFIX=""
fi
run_cmd() {
    $RUN_CMD_PREFIX "$@"
}

echo "Executing cleanup script"
echo "Region: $AWS_REGION"
echo "Profile: $AWS_PROFILE"
echo "Install ID: $TAG_VALUE"

VPC_IDS=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$TAG_VALUE" | jq -r '.Vpcs[].VpcId')
for vpc_id in $VPC_IDS; do
  echo "VPC: $vpc_id"
done

export AWS_PAGER=""

aws sts get-caller-identity > /dev/null || { echo "AWS credentials not set up"; exit 1; }

# Delete EKS Clusters
#
# Delete EKS Clusters (including Node Groups)
#
echo "Fetching EKS clusters with tag $TAG_KEY=$TAG_VALUE..."
CLUSTERS=$(aws eks list-clusters --query "clusters[]" --output text )

for CLUSTER in $CLUSTERS; do
    TAGS=$(aws eks describe-cluster --name "$CLUSTER" --query "cluster.tags" --output json 2>/dev/null)
    if echo "$TAGS" | grep -q "\"$TAG_KEY\": \"$TAG_VALUE\""; then
        echo "Deleting node groups for cluster: $CLUSTER..."
        NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER" --query "nodegroups[]" --output text)

        for NODE_GROUP in $NODE_GROUPS; do
            echo "Deleting node group: $NODE_GROUP in cluster: $CLUSTER..."
            run_cmd aws eks delete-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NODE_GROUP"
            echo "Waiting for node group $NODE_GROUP to be deleted..."
            run_cmd aws eks wait nodegroup-deleted --cluster-name "$CLUSTER" --nodegroup-name "$NODE_GROUP"
        done

        echo "Deleting EKS cluster: $CLUSTER..."
        run_cmd aws eks delete-cluster --name "$CLUSTER"
        echo "Waiting for EKS cluster $CLUSTER to be deleted..."
        run_cmd aws eks wait cluster-deleted --name "$CLUSTER"
    fi
done

#
# Delete ALBs associated with VPC above
#
echo "Fetching ALBs tagged with $TAG_KEY: $TAG_VALUE..."
LB_ARNS=$(aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn" --output text )

for LB_ARN in $LB_ARNS; do
    TAGS=$(aws elbv2 describe-tags --resource-arns "$LB_ARN" --query "TagDescriptions[].Tags[]" --output json)

    if echo "$TAGS" | jq -e 'map(select(.Key == "install.nuon.co/id" and .Value == "'"$TAG_VALUE"'")) | length > 0' > /dev/null; then
        echo "Deleting Load Balancer $LB_ARN..."
        run_cmd aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN"
        echo "Waiting for Load Balancer $LB_ARN to be deleted..."
        run_cmd aws elbv2 wait load-balancers-deleted --load-balancer-arns "$LB_ARN"
    fi
done

echo "ALB cleanup complete."

delete_vpc_resources() {
    local vpc_id="$1"
    echo "[ $vpc_id ] Cleaning up resources..."

    #
    # Delete Network Interfaces (ENIs)
    # NOTE: we only want to delete ENIs related to sandbox resources so we filter by sandbox.
    # The remaining ENIs w/out the tag should be deleted when the cluster compute is deleted since they correspond to nodes.
    echo "Looking for Network Interfaces in VPC $vpc_id..."
    aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$vpc_id" --filters "Name=tag:sandbox.nuon.co/name,Values=aws-eks" | jq -r '.NetworkInterfaces[].NetworkInterfaceId' | while read -r eni_id; do
        echo " - Deleting ENI $eni_id"
        run_cmd aws ec2 delete-network-interface --network-interface-id "$eni_id"
    done

    #
    # Disassociate and Delete Security Groups
    # NOTE: Here, we filter by the sandbox tag in addition to the install id to ensure we do not delete any sg's managed by the cloudformation.
    aws ec2 describe-security-groups --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" --filters "Name=tag:sandbox.nuon.co/name,Values=aws-eks" | jq -c '.SecurityGroups[]' | while read -r sg; do
        sg_id=$(echo "$sg" | jq -r '.GroupId')
        aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$sg_id" | jq -c '.SecurityGroupRules[]' | while read -r rule; do
            rule_id=$(echo "$rule" | jq -r '.SecurityGroupRuleId')
            direction=$(echo "$rule" | jq -r '.IsEgress')
            if [[ "$direction" == "true" ]]; then
                run_cmd aws ec2 revoke-security-group-egress --group-id "$sg_id" --security-group-rule-ids "$rule_id"
            else
                run_cmd aws ec2 revoke-security-group-ingress --group-id "$sg_id" --security-group-rule-ids "$rule_id"
            fi
        done

        echo " - Deleting security group $sg_id"
        run_cmd aws ec2 delete-security-group --group-id "$sg_id"
    done
}

# Iterate over all VPCs and delete resources
for vpc_id in $VPC_IDS; do
    delete_vpc_resources "$vpc_id"
done