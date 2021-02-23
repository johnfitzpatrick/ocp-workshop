#!/bin/bash

echo "Please enter your Sysdig keys."
read -p 'Sysdig Agent key: ' MYACCESSKEY
#read -p 'Sysdig Monitor API key: ' KUBE_MONITOR_API_TOKEN # UNUSED ATM
echo
echo "Select your Sysdig Secure base URL:"
echo
echo "    1. US East (https://secure.sysdig.com)"
echo "    2. US West (https://us2.app.sysdig.com)"
echo "    3. Europe  (https://eu1.app.sysdig.com)"
echo

while [ ! $REGION ]; do
	read -p "Region (1/2/3): " REGION

	case "$REGION" in
		1)
			export MYCOLLECTOR=collector.sysdigcloud.com
      export MYDOMAIN=secure.sysdig.com
			;;
		2)
			export MYCOLLECTOR=ingest-us2.app.sysdig.com
      export MYDOMAIN=us2.app.sysdig.com
			;;
		3)
			export MYCOLLECTOR=ingest-eu1.app.sysdig.com
      export MYDOMAIN=eu1.app.sysdig.com
			;;
		*)
			REGION=""
			;;
	esac
done
echo

export MYACCESSKEY
export MYDOMAIN
export MYCOLLECTOR

echo MYACCESSKEY: $MYACCESSKEY
echo MYDOMAIN: $MYDOMAIN
echo MYCOLLECTOR: $MYCOLLECTOR

# Update the configuration files
$ sed -i "s/ACCESSKEY/$MYACCESSKEY/g" sysdig-agent/sysdig-image-analyzer-configmap.yaml
$ sed -i "s/DOMAIN/$MYDOMAIN/g" sysdig-agent/sysdig-image-analyzer-configmap.yaml
$ sed -i "s/COLLECTOR/$MYCOLLECTOR/g" sysdig-agent/sysdig-agent-configmap.yaml

# Deploy the Sysdig Agent on your cluster
oc adm new-project sysdig-agent --node-selector='app=sysdig-agent'
oc label node --all "app=sysdig-agent"
oc project sysdig-agent
oc create serviceaccount sysdig-agent
oc adm policy add-scc-to-user privileged -n sysdig-agent -z sysdig-agent
oc adm policy add-cluster-role-to-user cluster-reader -n sysdig-agent -z sysdig-agent

oc create secret generic sysdig-agent --from-literal=access-key=$MYACCESSKEY -n sysdig-agent
oc apply -f sysdig-agent/sysdig-agent-configmap.yaml -n sysdig-agent
oc apply -f sysdig-agent/sysdig-agent-service.yaml -n sysdig-agent
oc apply -f sysdig-agent/sysdig-agent-daemonset-v2.yaml -n sysdig-agent

sleep 2
oc get pods

# Deploy the Sysdig Node Image Analyser
oc apply -f sysdig-agent/sysdig-image-analyzer-configmap.yaml -n sysdig-agent
oc apply -f sysdig-agent/sysdig-image-analyzer-daemonset.yaml -n sysdig-agent

sleep 2
oc get pods
