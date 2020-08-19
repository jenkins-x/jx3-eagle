#!/usr/bin/env bash
set -e
set -x

echo PATH=$PATH
echo HOME=$HOME

export PATH=$PATH:/usr/local/bin

# generic stuff...

# setup environment
KUBECONFIG="/tmp/jxhome/config"

#export XDG_CONFIG_HOME="/builder/home/.config"
mkdir -p /home/.config
cp -r /home/.config /builder/home/.config

jx version
jx help

export JX3_HOME=/home/.jx3
jx admin --help
jx secret --help





export GIT_USERNAME="jenkins-x-labs-bot"
export GIT_USER_EMAIL="jenkins-x@googlegroups.com"
export GH_OWNER="cb-kubecd"
export GIT_TOKEN="${GH_ACCESS_TOKEN//[[:space:]]}"


if [ -z "$GIT_TOKEN" ]
then
      echo "ERROR: no GH_ACCESS_TOKEN env var defined for bdd/ci.sh"
else
      echo "has valid git token in bdd/ci.sh"
fi

# batch mode for terraform
export TERRAFORM_APPROVE="-auto-approve"
export TERRAFORM_INPUT="-input=false"

export PROJECT_ID=jenkins-x-labs-bdd
export CREATED_TIME=$(date '+%a-%b-%d-%Y-%H-%M-%S')
export CLUSTER_NAME="${BRANCH_NAME,,}-$BUILD_NUMBER-$BDD_NAME"
export ZONE=europe-west1-c
export LABELS="branch=${BRANCH_NAME,,},cluster=$BDD_NAME,create-time=${CREATED_TIME,,}"

# lets setup git
git config --global --add user.name JenkinsXBot
git config --global --add user.email jenkins-x@googlegroups.com

echo "running the BDD test with JX_HOME = $JX_HOME"

mkdir -p $XDG_CONFIG_HOME/git
# replace the credentials file with a single user entry
echo "https://${GIT_USERNAME//[[:space:]]}:${GIT_TOKEN}@github.com" > $XDG_CONFIG_HOME/git/credentials

echo "using git credentials: $XDG_CONFIG_HOME/git/credentials"
ls -al $XDG_CONFIG_HOME/git/credentials

echo "creating cluster $CLUSTER_NAME in project $PROJECT_ID with labels $LABELS"

echo "lets get the PR head clone URL"
export PR_SOURCE_URL=$(jx gitops pr get --git-token=$GIT_TOKEN --head-url)

echo "using the version stream url $PR_SOURCE_URL ref: $PULL_PULL_SHA"

export GITOPS_TEMPLATE_URL="https://github.com/${GITOPS_TEMPLATE_PROJECT}.git"

# lets find the current template  version
export GITOPS_TEMPLATE_VERSION=$(grep  'version: ' /workspace/source/git/github.com/$GITOPS_TEMPLATE_PROJECT.yml | awk '{ print $2}')

echo "using GitOps template: $GITOPS_TEMPLATE_URL version: $GITOPS_TEMPLATE_VERSION"

# TODO support versioning?
#git clone -b v${GITOPS_TEMPLATE_VERSION} $GITOPS_TEMPLATE_URL

# create the boot git repository to mimic creating the git repository via the github create repository wizard
jx admin create -b --initial-git-url $GITOPS_TEMPLATE_URL --env dev --version-stream-ref=$PULL_PULL_SHA --version-stream-url=${PR_SOURCE_URL//[[:space:]]} --env-git-owner=$GH_OWNER --repo env-$CLUSTER_NAME-dev --no-operator

export GITOPS_REPO=https://${GIT_USERNAME//[[:space:]]}:${GIT_TOKEN}@github.com/${GH_OWNER}/env-${CLUSTER_NAME}-dev.git


if [ -z "$NO_JX_TEST" ]
then
    jx test create --test-url $GITOPS_REPO

    # lets garbage collect any old tests or previous failed tests of this repo/PR/context...
    jx test gc
else
      echo "not using jx-test to gc old tests"
fi

# avoid cloning cluster repo into the working CI folder
cd ..

git clone $GITOPS_REPO
cd env-${CLUSTER_NAME}-dev

# use the changes from this PR in the version stream for the cluster repo when resolving the helmfile
cp -R ../source versionStream
rm -rf versionStream/.git versionStream/.github
git add versionStream/

export GITOPS_DIR=`pwd`
export GITOPS_BIN=$GITOPS_DIR/bin

# lets configure git to use the project/cluster
$GITOPS_BIN/configure.sh

# lets create the cluster
$GITOPS_BIN/create.sh

# lets add / commit any cloud resource specific changes
git add * || true
git commit -a -m "chore: cluster changes" || true
git push

# now lets install the operator
# --username is found from $GIT_USERNAME or git clone URL
# --token is found from $GIT_TOKEN or git clone URL
jx admin operator

sleep 90

jx ns jx

# lets wait for things to be installed correctly
make verify-install

jx secret verify

# diagnostic commands to test the image's kubectl
kubectl version

# for some reason we need to use the full name once for the second command to work!
kubectl get environments
kubectl get env dev -oyaml
kubectl get cm config -oyaml

export JX_DISABLE_DELETE_APP="true"
export JX_DISABLE_DELETE_REPO="true"

# increase the timeout for complete PipelineActivity
export BDD_TIMEOUT_PIPELINE_ACTIVITY_COMPLETE="60"

# define variables for the BDD tests
export GIT_ORGANISATION="$GH_OWNER"
export GH_USERNAME="$GIT_USERNAME"

# lets turn off color output
export TERM=dumb

echo "about to run the bdd tests...."


# run the BDD tests
if [ -z "$RUN_TEST" ]
then
      bddjx -ginkgo.focus=golang -test.v
      #bddjx -ginkgo.focus=javascript -test.v
else
      $RUN_TEST
fi

echo "completed the bdd tests"

echo "switching context back to the infra cluster"

# lets connect back to the infra cluster so we can find the TestRun CRDs
gcloud container clusters get-credentials flash --zone europe-west1-b --project jx-labs-infra
jx ns jx


if [ -z "$NO_JX_TEST" ]
then
    echo "cleaning up cloud resources"
    jx test delete --test-url $GITOPS_REPO --dir=$GITOPS_DIR --script=$GITOPS_BIN/destroy.sh
else
    echo "not using jx-test to gc test resources"
fi



