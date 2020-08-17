#!/usr/bin/env bash
set -e
set -x

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

gcloud iam service-accounts delete $CLUSTER_NAME-dn@$PROJECT_ID.iam.gserviceaccount.com --project $PROJECT_ID --quiet
gcloud iam service-accounts delete $CLUSTER_NAME-jb@$PROJECT_ID.iam.gserviceaccount.com --project $PROJECT_ID --quiet
gcloud iam service-accounts delete $CLUSTER_NAME-bc@$PROJECT_ID.iam.gserviceaccount.com --project $PROJECT_ID --quiet
gcloud iam service-accounts delete $CLUSTER_NAME-tekton@$PROJECT_ID.iam.gserviceaccount.com --project $PROJECT_ID --quiet
gcloud iam service-accounts delete $CLUSTER_NAME-vo@$PROJECT_ID.iam.gserviceaccount.com --project $PROJECT_ID --quiet
gcloud iam service-accounts delete $CLUSTER_NAME-vt@$PROJECT_ID.iam.gserviceaccount.com --project $PROJECT_ID --quiet

gcloud container clusters delete $CLUSTER_NAME --project $PROJECT_ID --zone $ZONE --quiet
