#!/bin/bash

set -e

ZONE=${ZONE:-europe-west1-b}
LABELS=${LABELS:-mylabel=foo}

source `dirname "$0"`/setenv.sh

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

echo "creating a new cluster $CLUSTER_NAME in project $PROJECT_ID and region $ZONE"

# CLI-DOC-GEN-START
gcloud beta container clusters create $CLUSTER_NAME \
 --enable-autoscaling \
 --min-nodes=1 \
 --max-nodes=3 \
 --project=$PROJECT_ID \
 --workload-pool=$PROJECT_ID.svc.id.goog \
 --region=$ZONE \
 --labels=$LABELS \
 --machine-type=n1-standard-4 \
 --num-nodes=2
# CLI-DOC-GEN-END

jx gitops req edit --project $PROJECT_ID --cluster $CLUSTER_NAME --zone $ZONE

`dirname "$0"`/setup_resources.sh
