#!/bin/sh

set -eo pipefail

curl -s -X POST -H "X-AccessToken: ${CONTROL_VSHN_NET_TOKEN}" \
  https://control.vshn.net/api/servers/1/appuio/ \
  -d "{
    \"customer\": \"appuio\",
    \"fqdn\": \"${SERVER_FQDN}\",
    \"location\": \"exoscale\",
    \"region\": \"${SERVER_REGION}\",
    \"zone\": \"${SERVER_ZONE}\",
    \"environment\": \"AppuioLbaas\",
    \"project\": \"lbaas\",
    \"role\": \"lb\",
    \"stage\": \"${CLUSTER_ID}\"
  }"
