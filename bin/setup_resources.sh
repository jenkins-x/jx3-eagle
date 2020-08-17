#!/bin/bash

set -e

NAMESPACE=${NAMESPACE:-jx}

if [ -z $PROJECT_ID ]
then
  echo "Please supply the 'PROJECT_ID' environment variable for your GCP Project ID"
  echo "e.g."
  echo "export PROJECT_ID=myproject"
  exit 1
fi

if [ -z $CLUSTER_NAME ]
then
  echo "Please supply the 'CLUSTER_NAME' environment variable for your GKE cluster name"
  echo "e.g."
  echo "export CLUSTER_NAME=mycluster"
  exit 1
fi

function retry {
  set +e
  local max_attempts=${ATTEMPTS-5}
  local timeout=${TIMEOUT-3}
  local attempt=0
  local exitCode=0

  while [[ $attempt < $max_attempts ]]
  do
    "$@"
    exitCode=$?

    if [[ $exitCode == 0 ]]
    then
      break
    fi

    echo "Failure! Retrying in $timeout.." 1>&2
    sleep $timeout
    attempt=$(( attempt + 1 ))
    timeout=$(( timeout * 2 ))
  done

  if [[ $exitCode != 0 ]]
  then
    echo "You've failed me for the last time! ($@)" 1>&2
  fi

  return $exitCode
}



echo "setting up the cloud resources for ecluster $CLUSTER_NAME in project $PROJECT_ID"

export SLEEP="sleep 2"

gcloud config set project $PROJECT_ID

# enable secret manager
gcloud services enable secretmanager.googleapis.com

# setup the service accounts
gcloud iam service-accounts create $CLUSTER_NAME-bc --display-name=$CLUSTER_NAME-bc --project $PROJECT_ID
gcloud iam service-accounts create $CLUSTER_NAME-dn --display-name=$CLUSTER_NAME-dn --project $PROJECT_ID
gcloud iam service-accounts create $CLUSTER_NAME-sm --display-name=$CLUSTER_NAME-sm --project $PROJECT_ID
gcloud iam service-accounts create $CLUSTER_NAME-tekton --display-name=$CLUSTER_NAME-tekton --project $PROJECT_ID
gcloud iam service-accounts create $CLUSTER_NAME-vt --display-name=$CLUSTER_NAME-vt --project $PROJECT_ID

# TODO - still needed?
gcloud iam service-accounts create $CLUSTER_NAME-jb --display-name=$CLUSTER_NAME-jb --project $PROJECT_ID
gcloud iam service-accounts create $CLUSTER_NAME-vo --display-name=$CLUSTER_NAME-vo --project $PROJECT_ID

echo "creating namespace $NAMESPACE for project $PROJECT_ID"

cat `dirname "$0"`/setup.yaml.tmpl | sed "s/{namespace}/$NAMESPACE/" | sed "s/{project_id}/$PROJECT_ID/" | sed "s/{cluster_name}/$CLUSTER_NAME/" | kubectl apply --validate=false -f -

# change to the new jx namespace
jx ns $NAMESPACE
kubectl config set-context --current --namespace=$NAMESPACE


# external dns
retry gcloud iam service-accounts add-iam-policy-binding --quiet \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/external-dns]" \
  $CLUSTER_NAME-dn@$PROJECT_ID.iam.gserviceaccount.com \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/dns.admin \
  --member "serviceAccount:$CLUSTER_NAME-dn@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID


# jx boot - TODO still need?
retry gcloud iam service-accounts add-iam-policy-binding --quiet \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/jxl-boot]" \
  $CLUSTER_NAME-jb@$PROJECT_ID.iam.gserviceaccount.com \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/dns.admin \
  --member "serviceAccount:$CLUSTER_NAME-jb@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/viewer \
  --member "serviceAccount:$CLUSTER_NAME-jb@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/iam.serviceAccountKeyAdmin \
  --member "serviceAccount:$CLUSTER_NAME-jb@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/storage.admin \
  --member "serviceAccount:$CLUSTER_NAME-jb@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/storage.objectAdmin \
  --member "serviceAccount:$CLUSTER_NAME-jb@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/storage.objectCreator \
  --member "serviceAccount:$CLUSTER_NAME-jb@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/secretmanager.secretAccessor \
  --member "serviceAccount:$CLUSTER_NAME-jb@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

# tekton
retry gcloud iam service-accounts add-iam-policy-binding --quiet \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/tekton-bot]" \
  $CLUSTER_NAME-tekton@$PROJECT_ID.iam.gserviceaccount.com \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/viewer \
  --member "serviceAccount:$CLUSTER_NAME-tekton@$PROJECT_ID.iam.gserviceaccount.com" \

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/storage.admin \
  --member "serviceAccount:$CLUSTER_NAME-tekton@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/storage.objectAdmin \
  --member "serviceAccount:$CLUSTER_NAME-tekton@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/storage.objectCreator \
  --member "serviceAccount:$CLUSTER_NAME-tekton@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/secretmanager.secretAccessor \
  --member "serviceAccount:$CLUSTER_NAME-tekton@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

# secret manager
retry gcloud iam service-accounts add-iam-policy-binding --quiet \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/gsm-sa]" \
  $CLUSTER_NAME-sm@$PROJECT_ID.iam.gserviceaccount.com \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/secretmanager.secretAccessor \
  --member "serviceAccount:$CLUSTER_NAME-sm@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

# storage - for build controller to store logs etc
retry gcloud iam service-accounts add-iam-policy-binding --quiet \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/storage-sa]" \
  $CLUSTER_NAME-bc@$PROJECT_ID.iam.gserviceaccount.com \
  --project $PROJECT_ID

retry gcloud iam service-accounts add-iam-policy-binding --quiet \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/bucketrepo-bucketrepo]" \
  $CLUSTER_NAME-bc@$PROJECT_ID.iam.gserviceaccount.com \
  --project $PROJECT_ID

retry gcloud iam service-accounts add-iam-policy-binding --quiet \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/jxboot-helmfile-resources-controllerbuild]" \
  $CLUSTER_NAME-bc@$PROJECT_ID.iam.gserviceaccount.com \
  --project $PROJECT_ID


retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/storage.admin \
  --member "serviceAccount:$CLUSTER_NAME-bc@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/storage.objectAdmin \
  --member "serviceAccount:$CLUSTER_NAME-bc@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

# velero - TODO - still needed? could use -bc?
retry gcloud iam service-accounts add-iam-policy-binding --quiet \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/velero-sa]" \
  $CLUSTER_NAME-vo@$PROJECT_ID.iam.gserviceaccount.com \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/storage.admin \
  --member "serviceAccount:$CLUSTER_NAME-vo@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/storage.objectAdmin \
  --member "serviceAccount:$CLUSTER_NAME-vo@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/storage.objectCreator \
  --member "serviceAccount:$CLUSTER_NAME-vo@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

# vault
retry gcloud iam service-accounts add-iam-policy-binding --quiet \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/vault-sa]" \
  $CLUSTER_NAME-vt@$PROJECT_ID.iam.gserviceaccount.com \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/storage.objectAdmin \
  --member "serviceAccount:$CLUSTER_NAME-vt@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/cloudkms.admin \
  --member "serviceAccount:$CLUSTER_NAME-vt@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

retry gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/cloudkms.cryptoKeyEncrypterDecrypter \
  --member "serviceAccount:$CLUSTER_NAME-vt@$PROJECT_ID.iam.gserviceaccount.com" \
  --project $PROJECT_ID

