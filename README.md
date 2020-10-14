# Jenkins X 3.x GitOps Repository for the Jenkins X Infrastructure

This git repository setups the cloud resources required to run Jenkins X on GKE via Terraform and then sets up Jenkins X with [Google Secrets Manager](https://cloud.google.com/secret-manager).


## Prerequisites

We assume you have access to GCP and have modified the `main.mf` file to add your GCP project ID.

## Creating/upgrading cloud resources

Run the `./bin/apply.sh` script to generate the terraform resources and modify the `jx-requirements.yml` file

Now git commit and push any changes...

```bash 
git add *
git commit -a -m "chore: regenerated terraform"
```



