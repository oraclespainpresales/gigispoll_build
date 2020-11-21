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
echo Get Availability Domain...
availabilitydomainname=`oci iam availability-domain list --raw-output --query "data[0].name"`
echo Availability Domain: ${availabilitydomainname}
echo Create Stack...
stackocid=`oci resource-manager stack create --compartment-id ${compartmentid} --terraform-version 0.12.x --config-source /tmp/build/gigispoll_rm.zip --display-name ormgigispoll --variables '{"availability_domain":"'${availabilitydomainname}'","compartment_id":"'${compartmentid}'","shape":"VM.Standard.E2.1"}' --raw-output --query "data.id"`
echo Create Apply job...
jobocid=`oci resource-manager job create-apply-job --stack-id ${stackocid} --execution-plan-strategy AUTO_APPROVED --wait-for-state CANCELED --wait-for-state FAILED --wait-for-state SUCCEEDED --wait-interval-seconds 1 --raw-output --query "data.id"`
echo get Public IP...
publicip=`oci resource-manager job get-job-logs --job-id ${jobocid} --raw-output --query "data[?contains(\"message\", 'Public_IP')].message | [0]"`
publicip=`echo ${publicip#Public_IP = *}`
echo ${publicip}
echo Wait until Comput SSH cnx is available...
ssh -i /tmp/build/nopassphrase.key -o "StrictHostKeyChecking=no" opc@${publicip} 'exit'
while $? == 255 do
delay
retry
end while



echo Install and enable NGINX...
chmod 600 /tmp/build/nopassphrase.key
ssh -i /tmp/build/nopassphrase.key -o "StrictHostKeyChecking=no" opc@${publicip} 'sudo yum install -y -q nginx;sudo systemctl enable nginx;sudo systemctl start nginx;sudo firewall-cmd --zone=public --add-port=80/tcp --permanent;sudo firewall-cmd --reload'
echo Copy VBCS app on target Compute...
scp -i /tmp/build/nopassphrase.key -o "StrictHostKeyChecking=no" ./build/built-assets.zip  opc@${publicip}:/tmp
echo Unzip VBCS app...
ssh -i /tmp/build/nopassphrase.key -o "StrictHostKeyChecking=no" opc@${publicip} 'sudo unzip -qq /tmp/built-assets.zip -d /usr/share/nginx/html/gigispoll;sudo chown -R nginx:nginx /usr/share/nginx/html/gigispoll/'
echo Updating FN...
echo Retrieving Application Id...
applicationid=`oci fn application list --compartment-id ${compartmentid} --raw-output --query "data[?contains(\"display-name\", 'gigis-fn')].id | [0]"`
echo Retrieving Function Id...
functionid=`oci fn function list --application-id ${applicationid} --raw-output --query "data[?contains(\"display-name\", 'getnewuuid')].id | [0]"`
echo Updating Function Env Var...
newuri=`echo http://${publicip}/gigispoll/webApps/enterpoll/`
oci fn function update --function-id ${functionid} --config '{"VBCSURI":"'${newuri}'"}' --force
echo Done!!
