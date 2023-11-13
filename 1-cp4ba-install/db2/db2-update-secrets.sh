#!/bin/sh

set -e 

# project with DB2 Cluster CR deployed
DB2_NAMESPACE=${1:-"db2"}
# Project with secrets for CP4BA CR
CP4BA_NAMESPACE=${2:-"cp4ba"}


# fetches instancepassword secret and returns base64 encoded password
function fetch_db2_password {
    local DB2_SECRET=$(oc get secrets -n $DB2_NAMESPACE  | grep instancepassword | awk '{print $1}')
    
    echo "found secret $DB2_SECRET"

    DB2_PASSWORD=$(oc get secret -n $DB2_NAMESPACE $DB2_SECRET -o jsonpath='{..password}')
}

# patch value of secret when given secret name, key and new value
function patch_secret {
    local SECRET=$1
    local KEY=$2
    local NEW_VALUE=$3

    echo "patching secret: $SECRET key:$KEY"

    oc patch secret -n $CP4BA_NAMESPACE $SECRET --type='json' -p="[{\"op\": \"replace\", \"path\": \"$KEY\", \"value\":\"$NEW_VALUE\"}]"
}


function main {
    echo "fetching db2 instance password from db2 project: $DB2_NAMESPACE"
    fetch_db2_password

    echo "starting secret patch in namespace: $CP4BA_NAMESPACE"
    patch_secret ibm-fncm-secret /data/gcdDBPassword $DB2_PASSWORD
    patch_secret ibm-fncm-secret /data/os1DBPassword $DB2_PASSWORD
    patch_secret ibm-fncm-secret /data/os2DBPassword $DB2_PASSWORD
    patch_secret ibm-ban-secret /data/navigatorDBPassword $DB2_PASSWORD
    patch_secret ibm-dba-ums-secret /data/oauthDBPassword $DB2_PASSWORD
    patch_secret ibm-dba-ums-secret /data/tsDBPassword $DB2_PASSWORD
    echo "complete!"
}

main