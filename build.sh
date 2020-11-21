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
echo Create Stack...
stackocid=`oci resource-manager stack create --compartment-id ${compartmentid} --terraform-version 0.12.x --config-source /tmp/build/main.zip --display-name ormgigispoll --variables '{"compartment_id":"'${compartmentid}'","shape":"VM.Standard.E2.1"}' --raw-output --query "data.id"`
echo Create Apply job...
jobocid=`oci resource-manager job create-apply-job --stack-id ${stackocid} --execution-plan-strategy AUTO_APPROVED --wait-for-state CANCELED --wait-for-state FAILED --wait-for-state SUCCEEDED --wait-interval-seconds 1 --raw-output --query "data.id"`
echo get Public IP...
publicip=`oci resource-manager job get-job-logs --job-id ${jobocid} --raw-output --query "data[?contains(\"message\", 'Public_IP')].message | [0]"`
publicip=`echo ${publicip#Public_IP = *}`
echo ${publicip}
echo Install and enable NGINX...
chmod 600 /tmp/build/nopassphrase.key
ssh -i /tmp/build/nopassphrase.key -o "StrictHostKeyChecking=no" opc@${publicip} 'sudo yum install -y -q nginx;sudo systemctl enable nginx;sudo systemctl start nginx;sudo firewall-cmd --zone=public --add-port=80/tcp --permanent;sudo firewall-cmd --reload'
echo Copy VBCS app on target Compute...
scp -i /tmp/build/nopassphrase.key -o "StrictHostKeyChecking=no" ./build/built-assets.zip  opc@${publicip}:/tmp
echo Unzip VBCS app...
ssh -i nopassphrase.key -o "StrictHostKeyChecking=no" opc@${publicip} 'sudo unzip /tmp/built-assets.zip /usr/share/nginx/html'
