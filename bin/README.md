## Create Cloud Resources

This directory contains the scripts to setup a kubernetes cluster and cloud resources using the [gcloud](https://cloud.google.com/sdk/gcloud) command line tool.


### Prerequisites

You will need to [install gcloud](https://cloud.google.com/sdk/install).

These instructions assume you have cloned this git repository and run `cd` into the clone directory so that you can see this `README.md` file by running:

```bash 
ls -al bin/README.md
```

### Setup your cloud resources

Run the `./bin/create.sh` script:

```bash 
export PROJECT_ID="my-gcp-project"
export CLUSTER_NAME="my-gke-cluster"

./bin/create.sh
```

### Install the git operator

Please follow the [instructions on how to install the git operator](https://jenkins-x.io/docs/v3/guides/operator/) via the [jx admin operator](https://github.com/jenkins-x/jx-admin/blob/master/docs/cmd/jx-admin_operator.md) command:

```bash
jx admin operator
```

See the [how to install the git operator](https://jenkins-x.io/docs/v3/guides/operator/) 
