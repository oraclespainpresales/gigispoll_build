#!/bin/bash
echo Get target compartment...
# First, search for "DevOps" compartment:
compartmentid=`oci search resource free-text-search --text DevOps --raw-output --query "data.items[?contains(\"resource-type\", 'Compartment')].identifier | [0]"`
if [ -z "$compartmentid" ]
then
  # If doesn't exist, use root compartment
  compartmentid=`oci iam compartment list --all --compartment-id-in-subtree true --access-level ACCESSIBLE --include-root --raw-output --query "data[?contains(\"id\",'tenancy')].id | [0]"`
fi
echo Target compartment: ${compartmentid}
echo Looking for 'ormgigispoll' stacks...
stacks=`oci resource-manager stack list -c $compartmentid --raw-output --query "data[?contains(\"display-name\", 'ormgigispoll')].id"`
echo Stacks found:
echo ${stacks}
echo $stacks | jq -r -c '.[]' | while read stackocid; do
  echo Destroying stack ${stackocid}
  result=`oci resource-manager job create-destroy-job --stack-id ${stackocid} --execution-plan-strategy AUTO_APPROVED --wait-for-state CANCELED --wait-for-state FAILED --wait-for-state SUCCEEDED --wait-interval-seconds 1 --raw-output --query "data.\"lifecycle-state\""`
  echo Destroy operation for Stack ${stackocid}, result: ${result}
  oci resource-manager stack delete --stack-id ${stackocid} --force
  echo Stack ${stackocid} deleted
done
echo Done!!
