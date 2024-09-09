#!/bin/bash
#
# Copyright 2024 Tech Equity Cloud Services Ltd
# 
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#       http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# 
#################################################################################
##############      Explore Kubernetes Multicloud Clusters       ################
#################################################################################

function ask_yes_or_no() {
    read -p "$ $1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$ $1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=1 # $(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=1 # $(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo "Enter the cloud platform (GCP | AZURE | AWS)" | pv -qL 100
read PLATFORM
while [[ "${PLATFORM^^}" != "AWS" ]] && [[ "${PLATFORM^^}" != "AZURE" ]] && [[ "${PLATFORM^^}" != "GCP" ]]; do 
    echo "Enter the cloud platform. Valid options are GCP, AZURE, AWS" | pv -qL 100
    read PLATFORM
done

mkdir -p $HOME/gcp-gke-mc/${PLATFORM^^} > /dev/null 2>&1
export PROJDIR=$HOME/gcp-gke-mc/${PLATFORM^^}
export ENVDIR=$HOME/gcp-gke-mc
export SCRIPTNAME=gcp-gke-mc.sh
export AWS_CLUSTER=aws-eks-cluster
export AZURE_CLUSTER=azure-aks-cluster
export GCP_CLUSTER=gcp-gke-cluster

if [[ "${PLATFORM^^}" == "AWS" ]] ; then 
    if command -v $PROJDIR/aws/aws >/dev/null 2>&1; then
        echo
        echo "*** AWS CLI available ***"
    else
        echo
        echo "*** AWS CLI has not been installed ***"
    fi
    if command -v $PROJDIR/aws/eksctl >/dev/null 2>&1; then
        echo
        echo "*** eksctl CLI available ***"
    else
        echo
        echo "*** eksctl CLI has not been installed ***"
    fi
elif [[ "${PLATFORM^^}" == "AZURE" ]] ; then 
    if command -v /usr/bin/az >/dev/null 2>&1; then
        echo
        echo "*** Azure CLI available ***"
    else
        echo
        echo "*** Azure CLI has not been installed ***"
    fi
elif [[ "${PLATFORM^^}" == "GCP" ]] ; then 
    if command -v gcloud >/dev/null 2>&1; then
        echo
        echo "*** gcloud SDK available ***"
    else
        echo
        echo "*** gcloud SDK has not been installed ***"
    fi
fi

if [ -f "$ENVDIR/.env" ]; then
    source $ENVDIR/.env
else
cat <<EOF > $ENVDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=europe-west4
export GCP_ZONE=europe-west4-b
export GCP_NODE_TYPE=e2-standard-2
export AWS_LOCATION=us-west1 
export AWS_REGION=us-west-2
export AWS_NODE_TYPE=t3.medium
export AZURE_LOCATION=westus # westeurope
export AZURE_NODE_TYPE=Standard_D3_v2 # Standard_DS2_v2
export SERVICEMESH_VERSION=1.22.4-asm.0
export APPLICATION_NAME=hello-app
EOF
source $ENVDIR/.env
fi

export AZ_RESOURCEGROUP=aks-cluster-rg
echo

# Display menu options
while :
do
clear
cat<<EOF
===============================================
Configure Kubernetes on AWS, Azure and GCP
-----------------------------------------------
Please enter number to select your choice:
 (0) Switch between Preview, Create and Delete modes
 (1) Set cloud platform
 (2) Download SDK
 (3) Authenticate
 (4) Enable APIs
 (5) Create Kubernetes cluster
 (6) Register cluster to Anthos fleet
 (7) Configure IAM policies
 (8) Configure service mesh
 (9) Configure application
(10) Configure application artifacts
(11) Configure CI/CD artifacts
 (G) Launch user guide
 (Q) Quit
----------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $ENVDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $ENVDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $ENVDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $ENVDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        cat <<EOF > $ENVDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
export GCP_NODE_TYPE=$GCP_NODE_TYPE
export AWS_LOCATION=$AWS_LOCATION
export AWS_REGION=$AWS_REGION
export AWS_NODE_TYPE=$AWS_NODE_TYPE
export AZURE_LOCATION=$AZURE_LOCATION
export AZURE_NODE_TYPE=$AZURE_NODE_TYPE
export SERVICEMESH_VERSION=$SERVICEMESH_VERSION
export APPLICATION_NAME=$APPLICATION_NAME
EOF
        gsutil cp $ENVDIR/.env gs://${PROJECT_ID}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
        echo "*** Google Cloud node type is $GCP_NODE_TYPE ***" | pv -qL 100
        echo "*** AWS location is $AWS_LOCATION ***" | pv -qL 100
        echo "*** AWS region is $AWS_REGION ***" | pv -qL 100
        echo "*** AWS node type is $AWS_NODE_TYPE ***" | pv -qL 100
        echo "*** Azure location is $AZURE_LOCATION ***" | pv -qL 100
        echo "*** Azure node type is $AZURE_NODE_TYPE ***" | pv -qL 100
        echo "*** Istio version is $SERVICEMESH_VERSION ***" | pv -qL 100
        echo "*** Application name is $APPLICATION_NAME ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $ENVDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $ENVDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $ENVDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $ENVDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                cat <<EOF > $ENVDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
export GCP_NODE_TYPE=$GCP_NODE_TYPE
export AWS_LOCATION=$AWS_LOCATION
export AWS_REGION=$AWS_REGION
export AWS_NODE_TYPE=$AWS_NODE_TYPE
export AZURE_LOCATION=$AZURE_LOCATION
export AZURE_NODE_TYPE=$AZURE_NODE_TYPE
export SERVICEMESH_VERSION=$SERVICEMESH_VERSION
export APPLICATION_NAME=$APPLICATION_NAME
EOF
                gsutil cp $ENVDIR/.env gs://${PROJECT_ID}/${SCRIPTPATH}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
                echo "*** Google Cloud node type is $GCP_NODE_TYPE ***" | pv -qL 100
                echo "*** AWS location is $AWS_LOCATION ***" | pv -qL 100
                echo "*** AWS region is $AWS_REGION ***" | pv -qL 100
                echo "*** AWS node type is $AWS_NODE_TYPE ***" | pv -qL 100
                echo "*** Azure location is $AZURE_LOCATION ***" | pv -qL 100
                echo "*** Azure node type is $AZURE_NODE_TYPE ***" | pv -qL 100
                echo "*** Istio version is $SERVICEMESH_VERSION ***" | pv -qL 100
                echo "*** Application name is $APPLICATION_NAME ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $ENVDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $ENVDIR/.env
export STEP="${STEP},1"
echo
echo "Set the cloud platform (GCP | AZURE | AWS)" | pv -qL 100
read PLATFORM
while [[ "${PLATFORM^^}" != "AWS" ]] && [[ "${PLATFORM^^}" != "AZURE" ]] && [[ "${PLATFORM^^}" != "GCP" ]]; do 
    echo 
    echo "Enter the cloud platform. Valid options are AWS, AZURE or GCP" | pv -qL 100
    read PLATFORM
done
echo
echo "*** Platform is set to ${PLATFORM^^} ***" | pv -qL 100
if [[ "${PLATFORM^^}" == "AWS" ]] ; then 
    if command -v $PROJDIR/aws/aws >/dev/null 2>&1; then
        echo
        echo "*** AWS CLI available ***"
    else
        echo
        echo "*** AWS CLI has not been installed ***"
    fi
    if command -v $PROJDIR/aws/eksctl >/dev/null 2>&1; then
        echo
        echo "*** eksctl CLI available ***"
    else
        echo
        echo "*** eksctl CLI has not been installed ***"
    fi
elif [[ "${PLATFORM^^}" == "AZURE" ]] ; then 
    if command -v /usr/bin/az >/dev/null 2>&1; then
        echo
        echo "*** Azure CLI available ***"
    else
        echo
        echo "*** Azure CLI has not been installed ***"
    fi
elif [[ "${PLATFORM^^}" == "GCP" ]] ; then 
    if command -v gcloud >/dev/null 2>&1; then
        echo
        echo "*** gcloud SDK available ***"
    else
        echo
        echo "*** gcloud SDK has not been installed ***"
    fi
fi
mkdir -p $HOME/gcp-gke-mc/${PLATFORM^^} > /dev/null 2>&1
export PROJDIR=$HOME/gcp-gke-mc/${PLATFORM^^}
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $ENVDIR/.env
case ${PLATFORM^^} in
    AWS)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},2i"
            echo
            echo "$ curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" --output \$PROJDIR/awscliv2.zip # to download" | pv -qL 100
            echo
            echo "$ sudo \$PROJDIR/aws/install --bin-dir \$PROJDIR --install-dir \$PROJDIR --update # to install aws cli" | pv -qL 100
            echo
            echo "$ curl --silent --location \"https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_\$(uname -s)_amd64.tar.gz\" | tar xz -C /tmp # to download eksctl" | pv -qL 100
            echo
            echo "$ sudo git clone https://github.com/ahmetb/kubectx /tmp/kubectx # to clone repo" | pv -qL 100
        elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},2"
            echo
            echo "$ curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" --output $PROJDIR/awscliv2.zip # to download" | pv -qL 100
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" --output $PROJDIR/awscliv2.zip
            echo
            echo "$ unzip -o $PROJDIR/awscliv2.zip -d $PROJDIR # to unzip" | pv -qL 100
            unzip -o $PROJDIR/awscliv2.zip -d $PROJDIR 
            echo
            echo "$ sudo $PROJDIR/aws/install --bin-dir $PROJDIR --install-dir \$PROJDIR --update # to install aws cli" | pv -qL 100
            sudo $PROJDIR/aws/install --bin-dir $PROJDIR --install-dir $PROJDIR --update
            echo
            echo "$ curl --silent --location \"https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz\" | tar xz -C /tmp # to download eksctl" | pv -qL 100
            curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
            echo
            echo "$ sudo mv /tmp/eksctl $PROJDIR/aws # to move bin to path" | pv -qL 100
            sudo mv /tmp/eksctl $PROJDIR/aws
            echo
            echo "$ curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.5.9/aws-iam-authenticator_0.5.9_linux_amd64 # to download the aws-iam-authenticator binary" | pv -qL 100
            curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.5.9/aws-iam-authenticator_0.5.9_linux_amd64
            echo
            echo "$ mv aws-iam-authenticator $PROJDIR/aws # copy script" | pv -qL 100
            mv aws-iam-authenticator $PROJDIR/aws
            echo
            echo "$ chmod +x $PROJDIR/aws/aws-iam-authenticator # to change permission" | pv -qL 100
            chmod +x $PROJDIR/aws/aws-iam-authenticator
            echo
            echo "$ grep -q \"export PATH=${PROJDIR}:${PROJDIR}/aws\" ~/.bashrc || sed -i \"s|export PATH=|export PATH=${PROJDIR}:${PROJDIR}/aws:|g\" ~/.bashrc # to add path" | pv -qL 100
            if grep -q "${PROJDIR}:${PROJDIR}/aws" ~/.bashrc; then
                sed -i "s|export PATH=|export PATH=${PROJDIR}:${PROJDIR}/aws:|g" ~/.bashrc
            else
                echo "export PATH=${PROJDIR}:${PROJDIR}/aws:\$PATH" >> ~/.bashrc
            fi
            echo
            sudo rm -rf /tmp/kubectx
            echo "$ sudo git clone https://github.com/ahmetb/kubectx /tmp/kubectx # to clone repo" | pv -qL 100
            sudo git clone https://github.com/ahmetb/kubectx /tmp/kubectx
            echo
            echo "$ cp -rf /tmp/kubectx/kubectx $PROJDIR # to copy file" | pv -qL 100
            cp -rf /tmp/kubectx/kubectx $PROJDIR
            echo
            echo "$ cp -rf /tmp/kubectx/kubens $PROJDIR # to copy file" | pv -qL 100
            cp -rf /tmp/kubectx/kubens $PROJDIR
            echo
            sudo rm -rf /tmp/anthos-samples
            echo "$ git clone https://github.com/GoogleCloudPlatform/anthos-samples /tmp/anthos-samples # to clone repository" | pv -qL 100
            git clone https://github.com/GoogleCloudPlatform/anthos-samples /tmp/anthos-samples
            echo
            echo "$ cp -rf /tmp/anthos-samples/attached-logging-monitoring $PROJDIR # to copy yaml files" | pv -qL 100
            cp -rf /tmp/anthos-samples/attached-logging-monitoring $PROJDIR
            echo
            echo "$ ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<< y # to generate a key" | pv -qL 100
            ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa <<< y
            echo
            echo "*** An updated PATH variable is required by eksctl script to locate the aws and aws-iam-authenticator scripts ***"
            echo "*** This script will now exit. Run the script in a new shell, select step 0 to set the create mode and step 3 to continue ***"
            echo
            read -n 1 -s -r -p $'*** Press the Enter key to continue ***' | pv -qL 100
            source ~/.bashrc
            echo
            exec -l $SHELL # to restart shell        
       elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},2x"
            echo
            echo "$ sudo rm -rf $PROJDIR/anthos-samples # to delete folder" | pv -qL 100
            sudo rm -rf $PROJDIR/anthos-samples
        fi
    ;;
    AZURE)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},2i"
            echo
            echo "$ curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash # to install CLI" | pv -qL 100
            echo
            echo "$ sudo git clone https://github.com/ahmetb/kubectx /tmp/kubectx # to clone repo" | pv -qL 100
        elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},2"
            echo
            echo "$ sudo apt autoremove -y # to remove previous CLI installation" | pv -qL 100
            sudo apt autoremove -y
            echo
            echo "$ curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash # to install CLI" | pv -qL 100
            curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
            echo
            sudo sudo rm -rf /tmp/kubectx
            echo "$ sudo git clone https://github.com/ahmetb/kubectx /tmp/kubectx # to clone repo" | pv -qL 100
            sudo git clone https://github.com/ahmetb/kubectx /tmp/kubectx
            echo
            echo "$ cp -rf /tmp/kubectx/kubectx $PROJDIR # to copy file" | pv -qL 100
            cp -rf /tmp/kubectx/kubectx $PROJDIR
            echo
            echo "$ cp -rf /tmp/kubectx/kubens $PROJDIR # to copy file" | pv -qL 100
            cp -rf /tmp/kubectx/kubens $PROJDIR
            echo
            sudo rm -rf /tmp/anthos-samples
            echo "$ git clone https://github.com/GoogleCloudPlatform/anthos-samples /tmp/anthos-samples # to clone repository" | pv -qL 100
            git clone https://github.com/GoogleCloudPlatform/anthos-samples /tmp/anthos-samples
            echo
            echo "$ cp -rf /tmp/anthos-samples/attached-logging-monitoring $PROJDIR # to copy yaml files" | pv -qL 100
            cp -rf /tmp/anthos-samples/attached-logging-monitoring $PROJDIR
        elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},2x"
            echo
            echo "$ sudo rm -rf $PROJDIR/anthos-samples # to delete folder" | pv -qL 100
            sudo rm -rf $PROJDIR/anthos-samples
        fi
    ;;
    GCP)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},2i"
            echo
            echo "$ sudo git clone https://github.com/ahmetb/kubectx /tmp/kubectx # to clone repo" | pv -qL 100
        elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},2"
            echo
            sudo sudo rm -rf /tmp/kubectx
            echo "$ sudo git clone https://github.com/ahmetb/kubectx /tmp/kubectx # to clone repo" | pv -qL 100
            sudo git clone https://github.com/ahmetb/kubectx /tmp/kubectx
            echo
            echo "$ cp -rf /tmp/kubectx/kubectx $PROJDIR # to copy file" | pv -qL 100
            cp -rf /tmp/kubectx/kubectx $PROJDIR
            echo
            echo "$ cp -rf /tmp/kubectx/kubens $PROJDIR # to copy file" | pv -qL 100
            cp -rf /tmp/kubectx/kubens $PROJDIR
        elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},2x"
            echo
            echo "$ sudo rm -rf $PROJDIR/anthos-samples # to delete folder" | pv -qL 100
            sudo rm -rf $PROJDIR/anthos-samples
       fi    
    ;;
esac
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $ENVDIR/.env
case ${PLATFORM^^} in
    AWS)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},3i"
            echo 
            echo "$ \$PROJDIR/aws/aws configure # to configure credentials" | pv -qL 100
        elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},3"
            gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
            gcloud config set aws/location $AWS_LOCATION > /dev/null 2>&1 
            $PROJDIR/aws/aws configure set default.region $AWS_REGION > /dev/null 2>&1 
            $PROJDIR/aws/aws configure set default.output json > /dev/null 2>&1 
            echo 
            echo "$ $PROJDIR/aws/aws configure # to configure credentials" | pv -qL 100
            $PROJDIR/aws/aws configure
        elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},3x"
            echo
            echo "*** Nothing to delete ***" | pv -qL 100
        fi
    ;;
    AZURE)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},3i"
            echo
            echo "$ /usr/bin/az login --use-device-code # to log on to Azure account" | pv -qL 100
        elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},3"
            echo
            echo "$ /usr/bin/az login --use-device-code # to log on to Azure account" | pv -qL 100
            /usr/bin/az login --use-device-code
        elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},3x"
            echo
            echo "*** Nothing to delete ***" | pv -qL 100
        fi
    ;;
    GCP)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},3i"
            echo 
            echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
        elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},3"
            gcloud config set project $GCP_PROJECT > /dev/null 2>&1
            if [[ -f $ENVDIR/.${GCP_PROJECT}.json ]]; then
                echo 
                echo "*** Authenticating using service account key $ENVDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
            else
                while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                    echo 
                    echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                    gcloud auth login  --brief --quiet
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet
                    sleep 5
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)') 
                done
            echo
            echo "*** Authenticated ***"
            fi
        elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},3x"
            echo
            echo "*** Nothing to delete ***" | pv -qL 100
        fi
    ;;
esac
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $ENVDIR/.env
case ${PLATFORM^^} in
    AWS)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},4i"
            echo
            echo "$ gcloud --project \$GCP_PROJECT services enable gkemulticloud.googleapis.com connectgateway.googleapis.com container.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com serviceusage.googleapis.com anthos.googleapis.com logging.googleapis.com monitoring.googleapis.com stackdriver.googleapis.com storage-api.googleapis.com storage-component.googleapis.com securetoken.googleapis.com sts.googleapis.com opsconfigmonitoring.googleapis.com mesh.googleapis.com containersecurity.googleapis.com anthosconfigmanagement.googleapis.com anthospolicycontroller.googleapis.com # to enable APIs" | pv -qL 100
         elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},4"
            gcloud config set project $GCP_PROJECT > /dev/null 2>&1
            echo
            echo "$ gcloud --project $GCP_PROJECT services enable gkemulticloud.googleapis.com connectgateway.googleapis.com container.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com serviceusage.googleapis.com anthos.googleapis.com logging.googleapis.com monitoring.googleapis.com stackdriver.googleapis.com storage-api.googleapis.com storage-component.googleapis.com securetoken.googleapis.com sts.googleapis.com opsconfigmonitoring.googleapis.com mesh.googleapis.com containersecurity.googleapis.com anthosconfigmanagement.googleapis.com anthospolicycontroller.googleapis.com # to enable APIs" | pv -qL 100
            gcloud --project $GCP_PROJECT services enable gkemulticloud.googleapis.com connectgateway.googleapis.com container.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com serviceusage.googleapis.com anthos.googleapis.com logging.googleapis.com monitoring.googleapis.com stackdriver.googleapis.com storage-api.googleapis.com storage-component.googleapis.com securetoken.googleapis.com sts.googleapis.com opsconfigmonitoring.googleapis.com mesh.googleapis.com containersecurity.googleapis.com anthosconfigmanagement.googleapis.com anthospolicycontroller.googleapis.com 
        elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},4x"
            echo
            echo "*** Nothing to delete ***" | pv -qL 100
        else
            export STEP="${STEP},4i"
            echo
            echo "1. Enable APIs" | pv -qL 100
        fi
    ;;
    AZURE)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},4i"
            echo
            echo "$ /usr/bin/az group create -l \${AZURE_LOCATION} -n \${AZ_RESOURCEGROUP} # create resource group" | pv -qL 100
            echo
            echo "$ /usr/bin/az account set -s \$(/usr/bin/az account list --query '[?isDefault].id' -o tsv) # to set account" | pv -qL 100
            echo
            echo "$ /usr/bin/az configure --defaults location=\${AZURE_LOCATION} # to configure location" | pv -qL 100
            echo
            echo "$ /usr/bin/az configure --defaults group=\${AZ_RESOURCEGROUP} # to configure group" | pv -qL 100
            echo
            echo "$ gcloud --project \$GCP_PROJECT services enable gkemulticloud.googleapis.com connectgateway.googleapis.com container.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com serviceusage.googleapis.com anthos.googleapis.com logging.googleapis.com monitoring.googleapis.com stackdriver.googleapis.com storage-api.googleapis.com storage-component.googleapis.com securetoken.googleapis.com sts.googleapis.com anthos.googleapis.com opsconfigmonitoring.googleapis.com mesh.googleapis.com containersecurity.googleapis.com anthosconfigmanagement.googleapis.com anthospolicycontroller.googleapis.com # to enable APIs" | pv -qL 100
        elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},4"
            echo
            echo "$ /usr/bin/az group create -l ${AZURE_LOCATION} -n ${AZ_RESOURCEGROUP} # create resource group" | pv -qL 100
            /usr/bin/az group create -l ${AZURE_LOCATION} -n ${AZ_RESOURCEGROUP}
            echo
            echo "$ /usr/bin/az account set -s \$(/usr/bin/az account list --query '[?isDefault].id' -o tsv) # to set account" | pv -qL 100
            /usr/bin/az account set -s $(/usr/bin/az account list --query '[?isDefault].id' -o tsv)
            echo
            echo "$ /usr/bin/az configure --defaults location=${AZURE_LOCATION} # to configure location" | pv -qL 100
            /usr/bin/az configure --defaults location=${AZURE_LOCATION}
            echo
            echo "$ /usr/bin/az configure --defaults group=${AZ_RESOURCEGROUP} # to configure group" | pv -qL 100
            /usr/bin/az configure --defaults group=${AZ_RESOURCEGROUP}
            echo
            echo "$ gcloud --project $GCP_PROJECT services enable gkemulticloud.googleapis.com connectgateway.googleapis.com container.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com serviceusage.googleapis.com anthos.googleapis.com logging.googleapis.com monitoring.googleapis.com stackdriver.googleapis.com storage-api.googleapis.com storage-component.googleapis.com securetoken.googleapis.com sts.googleapis.com anthos.googleapis.com opsconfigmonitoring.googleapis.com mesh.googleapis.com containersecurity.googleapis.com anthosconfigmanagement.googleapis.com anthospolicycontroller.googleapis.com # to enable APIs" | pv -qL 100
            gcloud --project $GCP_PROJECT services enable gkemulticloud.googleapis.com connectgateway.googleapis.com container.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com serviceusage.googleapis.com anthos.googleapis.com logging.googleapis.com monitoring.googleapis.com stackdriver.googleapis.com storage-api.googleapis.com storage-component.googleapis.com securetoken.googleapis.com sts.googleapis.com anthos.googleapis.com opsconfigmonitoring.googleapis.com mesh.googleapis.com containersecurity.googleapis.com anthosconfigmanagement.googleapis.com anthospolicycontroller.googleapis.com 
       elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},4x"
            echo
            echo "$ /usr/bin/az group delete --name ${AZ_RESOURCEGROUP} --yes # delete resource group" | pv -qL 100
            /usr/bin/az group delete --name ${AZ_RESOURCEGROUP} --yes >/dev/null 2>&1
        else
            export STEP="${STEP},4i"
            echo
            echo "1. Create resource group" | pv -qL 100
        fi
    ;;
    GCP)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},4i"
            echo
            echo "$ gcloud --project \$GCP_PROJECT services enable gkemulticloud.googleapis.com connectgateway.googleapis.com container.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com serviceusage.googleapis.com anthos.googleapis.com logging.googleapis.com monitoring.googleapis.com stackdriver.googleapis.com storage-api.googleapis.com storage-component.googleapis.com securetoken.googleapis.com sts.googleapis.com anthos.googleapis.com opsconfigmonitoring.googleapis.com mesh.googleapis.com containersecurity.googleapis.com anthosconfigmanagement.googleapis.com anthospolicycontroller.googleapis.com # to enable APIs" | pv -qL 100
         elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},4"
            gcloud config set project $GCP_PROJECT > /dev/null 2>&1
            echo
            echo "$ gcloud --project $GCP_PROJECT services enable gkemulticloud.googleapis.com connectgateway.googleapis.com container.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com serviceusage.googleapis.com anthos.googleapis.com logging.googleapis.com monitoring.googleapis.com stackdriver.googleapis.com storage-api.googleapis.com storage-component.googleapis.com securetoken.googleapis.com sts.googleapis.com anthos.googleapis.com opsconfigmonitoring.googleapis.com mesh.googleapis.com containersecurity.googleapis.com anthosconfigmanagement.googleapis.com anthospolicycontroller.googleapis.com # to enable APIs" | pv -qL 100
            gcloud --project $GCP_PROJECT services enable gkemulticloud.googleapis.com connectgateway.googleapis.com container.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com serviceusage.googleapis.com anthos.googleapis.com logging.googleapis.com monitoring.googleapis.com stackdriver.googleapis.com storage-api.googleapis.com storage-component.googleapis.com securetoken.googleapis.com sts.googleapis.com anthos.googleapis.com opsconfigmonitoring.googleapis.com mesh.googleapis.com containersecurity.googleapis.com anthosconfigmanagement.googleapis.com anthospolicycontroller.googleapis.com 
        elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},4x"
            echo
            echo "*** Nothing to delete ***" | pv -qL 100
        else
            export STEP="${STEP},4i"
            echo
            echo "1. Enable APIs" | pv -qL 100
        fi
    ;;
esac
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $ENVDIR/.env
case ${PLATFORM^^} in
    AWS)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},5i"
            echo
            echo "$ \$PROJDIR/aws/eksctl create cluster --name \$AWS_CLUSTER --node-type \$AWS_NODE_TYPE --nodes 5 --nodes-min 5 --nodes-max 10 --region \$AWS_REGION --version 1.29 --spot --full-ecr-access --ssh-access # to create cluster" | pv -qL 100
            echo
            echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
            echo
            echo "$ \$PROJDIR/aws/aws eks update-kubeconfig --region \$AWS_REGION --name \$AWS_CLUSTER # to update cluster credentials" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx eks=. # to set context"
        elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},5"
            echo
            cd $PROJDIR/aws
            echo "$ $PROJDIR/aws/eksctl create cluster --name $AWS_CLUSTER --node-type $AWS_NODE_TYPE --nodes 5 --nodes-min 5 --nodes-max 10 --region $AWS_REGION --version 1.29 --spot --full-ecr-access --ssh-access # to create cluster" | pv -qL 100
            $PROJDIR/aws/eksctl create cluster --name $AWS_CLUSTER --node-type $AWS_NODE_TYPE --nodes 5 --nodes-min 5 --nodes-max 10 --region $AWS_REGION --version 1.29 --spot --full-ecr-access --ssh-access 
            echo
            echo "$ chmod 700 ~/.kube/config # to restrict access to config file" | pv -qL 100
            chmod 700 ~/.kube/config
            echo
            echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
            kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
            echo
            echo "$ $PROJDIR/aws/aws eks update-kubeconfig --region $AWS_REGION --name $AWS_CLUSTER # to update cluster credentials" | pv -qL 100
            $PROJDIR/aws/aws eks update-kubeconfig --region $AWS_REGION --name $AWS_CLUSTER
            echo
            echo "$ $PROJDIR/kubectx eks=. # to set context"
            $PROJDIR/kubectx eks=.
        elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},5x"
            echo
            echo "$ $PROJDIR/aws/eksctl delete cluster --name $AWS_CLUSTER # to delete cluster" | pv -qL 100
            $PROJDIR/aws/eksctl delete cluster --name $AWS_CLUSTER
        else
            export STEP="${STEP},5i"
            echo
            echo "1. Create Kubernetes cluster" | pv -qL 100
            echo "2. Assign cluster admin role" | pv -qL 100
        fi
    ;;
    AZURE)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},5i"
            echo
            echo "$ /usr/bin/az aks create --resource-group \$AZ_RESOURCEGROUP --name \$AZURE_CLUSTER --node-count 2 --node-vm-size \$AZURE_NODE_TYPE --enable-cluster-autoscaler --min-count 2 --max-count 4 --enable-addons monitoring --generate-ssh-keys --kubernetes-version 1.29 # to create cluster" | pv -qL 100
            echo
            echo "$ /usr/bin/az aks nodepool add --resource-group \$AZ_RESOURCEGROUP --cluster-name \$AZURE_CLUSTER --name spotnodepool --priority Spot --eviction-policy Delete --spot-max-price -1 --enable-cluster-autoscaler --min-count 1 --max-count 10 --no-wait # to add spot node pool" | pv -qL 100
            echo      
            echo "$ /usr/bin/az aks get-credentials -n \$AZURE_CLUSTER -g \$AZ_RESOURCEGROUP # to get container credentials" | pv -qL 100
            echo
            echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx aks=. # to set context"
        elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},5"
            echo
            echo "$ /usr/bin/az aks create --resource-group $AZ_RESOURCEGROUP --name $AZURE_CLUSTER --node-count 5 --node-vm-size $AZURE_NODE_TYPE --enable-cluster-autoscaler --min-count 5 --max-count 10 --enable-addons monitoring --generate-ssh-keys --kubernetes-version 1.29 --enable-addons http_application_routing # to create cluster" | pv -qL 100
            /usr/bin/az aks create --resource-group $AZ_RESOURCEGROUP --name $AZURE_CLUSTER --node-count 5 --node-vm-size $AZURE_NODE_TYPE --enable-cluster-autoscaler --min-count 5 --max-count 10 --enable-addons monitoring --generate-ssh-keys --kubernetes-version 1.29 --enable-addons http_application_routing 
            # echo
            # echo "$ /usr/bin/az aks nodepool add --resource-group $AZ_RESOURCEGROUP --cluster-name $AZURE_CLUSTER --name spotnodepool --priority Spot --eviction-policy Delete --spot-max-price -1 --enable-cluster-autoscaler --min-count 1 --max-count 10 --no-wait # to add spot node pool" | pv -qL 100
            # /usr/bin/az aks nodepool add --resource-group $AZ_RESOURCEGROUP --cluster-name $AZURE_CLUSTER --name spotnodepool --priority Spot --eviction-policy Delete --spot-max-price -1 --enable-cluster-autoscaler --min-count 1 --max-count 10 --no-wait
            echo      
            echo "$ /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP # to get container credentials" | pv -qL 100
            /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP
            echo
            echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
            kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
            echo
            echo "$ $PROJDIR/kubectx aks=. # to set context"
            $PROJDIR/kubectx aks=.
        elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},5x"
            echo
            echo "$ /usr/bin/az aks delete --name $AZURE_CLUSTER --resource-group $AZ_RESOURCEGROUP # to delete cluster" | pv -qL 100
            /usr/bin/az aks delete --name $AZURE_CLUSTER --resource-group $AZ_RESOURCEGROUP
        else
            export STEP="${STEP},5i"
            echo
            echo "1. Create container cluster" | pv -qL 100
            echo "2. Retrieve the credentials for cluster" | pv -qL 100
        fi
    ;;
    GCP)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},5i"
            echo
            echo "$ gcloud beta container clusters create \$GCP_CLUSTER --zone \$GCP_ZONE --machine-type \$GCP_NODE_TYPE --num-nodes 5 --spot --gateway-api=standard --workload-pool=\${WORKLOAD_POOL} # to create container cluster" | pv -qL 100
            echo
            echo "$ gcloud container clusters get-credentials \$GCP_CLUSTER --zone \$GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
            echo
            echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx gke=. # to set context"
        elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},5"
            gcloud config set project $GCP_PROJECT > /dev/null 2>&1
            gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
            export PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT --format="value(projectNumber)")
            export WORKLOAD_POOL=${GCP_PROJECT}.svc.id.goog
            echo
            echo "$ gcloud beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --machine-type $GCP_NODE_TYPE --num-nodes 5 --spot --gateway-api=standard --workload-pool=${WORKLOAD_POOL} # to create container cluster" | pv -qL 100
            gcloud beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --machine-type $GCP_NODE_TYPE --num-nodes 5 --spot --gateway-api=standard --workload-pool=${WORKLOAD_POOL} 
            echo
            echo "$ gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
            gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE
            echo
            echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
            kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
            echo
            echo "$ $PROJDIR/kubectx gke=. # to set context"
            $PROJDIR/kubectx gke=.
        elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},5x"
            gcloud config set project $GCP_PROJECT > /dev/null 2>&1
            gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
            echo
            echo "$ gcloud beta container clusters delete $GCP_CLUSTER --zone $GCP_ZONE # to delete cluster" | pv -qL 100
            gcloud beta container clusters delete $GCP_CLUSTER --zone $GCP_ZONE 
        else
            export STEP="${STEP},5i"
            echo
            echo "1. Create GKE cluster" | pv -qL 100
            echo "2. Grant cluster admin role to current user" | pv -qL 100
        fi
    ;;
esac
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"6")
start=`date +%s`
source $ENVDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},6i"
    case ${PLATFORM^^} in
        AWS)
            echo
            echo "$ \$PROJDIR/aws/aws eks update-kubeconfig --region \$AWS_REGION --name \$AWS_CLUSTER # to update cluster credentials" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx eks # to switch context"
        ;;
        AZURE)
            echo
            echo "$ /usr/bin/az aks get-credentials -n \$AZURE_CLUSTER -g \$AZ_RESOURCEGROUP # to retrieve cluster credentials" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx aks # to switch context"
        ;;
        GCP)
            echo
            echo "$ gcloud container clusters get-credentials \$GCP_CLUSTER --zone \$GCP_ZONE # to retrieve cluster credentials" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx gke # to switch context"
        ;;
    esac
    echo
    echo "$ gcloud services enable --project=\$GCP_PROJECT container.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com iam.googleapis.com anthosidentityservice.googleapis.com connectgateway.googleapis.com anthos.googleapis.com # to enable APIs" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=\"serviceAccount:\$GCP_PROJECT.svc.id.goog[gke-system/gke-telemetry-agent]\" --role=roles/gkemulticloud.telemetryWriter --no-user-output-enabled # to enable system container logging and container metrics" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=\"serviceAccount:\$CLOUDBUILD_SA\" --role=\"roles/gkehub.gatewayAdmin\" --no-user-output-enabled # to enable user to access the Connect gateway API" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=\"serviceAccount:\$CLOUDBUILD_SA\" --role=\"roles/gkehub.viewer\" --no-user-output-enabled # to enable a user retrieve cluster kubeconfigs" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=\"serviceAccount:\$CLOUDBUILD_SA\" --role=\"roles/container.viewer\" --no-user-output-enabled # to enable user to view GKE Clusters" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=\"serviceAccount:\$CLOUDBUILD_SA\" --role=\"roles/gkehub.viewer\" --no-user-output-enabled # to enable user to view clusters outside Google Cloud" | pv -qL 100
    case ${PLATFORM^^} in
        AWS)
            echo
            echo "$ \$PROJDIR/aws/eksctl utils associate-iam-oidc-provider --cluster \$AWS_CLUSTER --approve # to create an IAM OIDC identity provider" | pv -qL 100
            echo
            echo "$ \$PROJDIR/aws/eksctl utils associate-iam-oidc-provider --cluster \$AWS_CLUSTER --approve # to create IAM OIDC identity provider" | pv -qL 100
            echo
            echo "$ \$PROJDIR/aws/aws eks update-kubeconfig --name \$AWS_CLUSTER --region \$AWS_REGION # to update kubeconfig" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx eks # to switch context" | pv -qL 100
            echo
            echo "$ gcloud container hub memberships register \$AWS_CLUSTER --context=\$(kubectl config current-context) --kubeconfig=~/.kube/config --enable-workload-identity --public-issuer-url \$OIDC_URL --quiet # to register cluster" | pv -qL 100
            echo
            echo "$ gcloud container hub memberships get-credentials \$AWS_CLUSTER # to set context" | pv -qL 100
            echo
            echo "$ \$PROJDIR/aws/eksctl utils update-cluster-logging --enable-types=all --region=\$AWS_REGION --cluster=\$AWS_CLUSTER --approve # to enable logging" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx eks # to switch context" | pv -qL 100
            echo
            echo "$ gcloud beta container fleet memberships generate-gateway-rbac --membership=\$AWS_CLUSTER --role=clusterrole/cluster-admin --users=\$EMAIL --project=\$GCP_PROJECT --context \$(kubectl config current-context) --kubeconfig \$HOME/.kube/config --apply # to enable clusters to authorize requests from Google Cloud console" | pv -qL 100
            echo
            echo "$ gcloud beta container fleet memberships generate-gateway-rbac --membership=\$AWS_CLUSTER --role=clusterrole/cluster-admin --users=\$CLOUDBUILD_SA --project=\$GCP_PROJECT --context \$(kubectl config current-context) --kubeconfig \$HOME/.kube/config --apply # to enable clusters to authorize requests from cloud build" | pv -qL 100    
        ;;
        AZURE)
            echo
            echo "$ /usr/bin/az aks get-credentials -n \$AZURE_CLUSTER -g \$AZ_RESOURCEGROUP # to retrieve cluster credentials" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx aks # to switch context" | pv -qL 100
            echo
            echo "$ gcloud container hub memberships register \$AZURE_CLUSTER --context=\$(kubectl config current-context) --kubeconfig=~/.kube/config --enable-workload-identity --has-private-issuer --quiet # to register cluster" | pv -qL 100
            echo
            echo "$ gcloud container hub memberships get-credentials \$AZURE_CLUSTER # to set context" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx aks # to switch context" | pv -qL 100
            echo
            echo "$ gcloud beta container fleet memberships generate-gateway-rbac --membership=\$AZURE_CLUSTER --role=clusterrole/cluster-admin --users=\$EMAIL --project=\$GCP_PROJECT --context \$(kubectl config current-context) --kubeconfig \$HOME/.kube/config --apply # to enable clusters to authorize requests from Google Cloud console" | pv -qL 100
            echo
            echo "$ gcloud beta container fleet memberships generate-gateway-rbac --membership=\$AZURE_CLUSTER --role=clusterrole/cluster-admin --users=\$CLOUDBUILD_SA --project=\$GCP_PROJECT --context \$(kubectl config current-context) --kubeconfig \$HOME/.kube/config --apply # to enable clusters to authorize requests from cloud build" | pv -qL 100    
        ;;
        GCP)
            echo
            echo "$ gcloud container clusters get-credentials \$GCP_CLUSTER --zone \$GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx gke # to switch context" | pv -qL 100
            echo
            echo "$ gcloud container fleet memberships register \$GCP_CLUSTER --gke-cluster=\$GCP_ZONE/\$GCP_CLUSTER --enable-workload-identity # to register cluster" | pv -qL 100
            echo
            echo "$ gcloud container hub memberships get-credentials \$GCP_CLUSTER # to set context" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx gke # to switch context" | pv -qL 100
            echo
            echo "$ gcloud beta container fleet memberships generate-gateway-rbac --membership=\$GCP_CLUSTER --role=clusterrole/cluster-admin --users=\$EMAIL --project=\$GCP_PROJECT --context \$(kubectl config current-context) --kubeconfig \$HOME/.kube/config --apply # to enable clusters to authorize requests from Google Cloud console" | pv -qL 100
            echo
            echo "$ gcloud beta container fleet memberships generate-gateway-rbac --membership=\$GCP_CLUSTER --role=clusterrole/cluster-admin --users=\$CLOUDBUILD_SA --project=\$GCP_PROJECT --context \$(kubectl config current-context) --kubeconfig \$HOME/.kube/config --apply # to enable clusters to authorize requests from cloud build" | pv -qL 100
        ;;
    esac
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},6"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    export KUBECONFIG=~/.kube/config # to set the KUBECONFIG environment variable
    case ${PLATFORM^^} in
        AWS)
            echo
            echo "$ $PROJDIR/aws/aws eks update-kubeconfig --region $AWS_REGION --name $AWS_CLUSTER # to update cluster credentials" | pv -qL 100
            $PROJDIR/aws/aws eks update-kubeconfig --region $AWS_REGION --name $AWS_CLUSTER
            echo
            echo "$ $PROJDIR/kubectx eks # to switch context" | pv -qL 100
            $PROJDIR/kubectx eks
        ;;
        AZURE)
            echo
            echo "$ /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP # to retrieve cluster credentials" | pv -qL 100
            /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP
            echo
            echo "$ $PROJDIR/kubectx aks # to switch context" | pv -qL 100
            $PROJDIR/kubectx aks
        ;;
        GCP)
            echo
            echo "$ gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE # to retrieve cluster credentials" | pv -qL 100
            gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE
            echo
            echo "$ $PROJDIR/kubectx gke # to switch context" | pv -qL 100
            $PROJDIR/kubectx gke
        ;;
    esac
    cd $PROJDIR
    PROJECT_NUMBER=$(gcloud --project $GCP_PROJECT projects describe $GCP_PROJECT --format="value(projectNumber)")
    CLOUDBUILD_SA=${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
    echo
    echo "$ gcloud services enable --project=$GCP_PROJECT container.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com iam.googleapis.com anthosidentityservice.googleapis.com connectgateway.googleapis.com anthos.googleapis.com # to enable APIs" | pv -qL 100
    gcloud services enable --project=$GCP_PROJECT container.googleapis.com gkeconnect.googleapis.com gkehub.googleapis.com iam.googleapis.com anthosidentityservice.googleapis.com connectgateway.googleapis.com anthos.googleapis.com
    echo
    echo "$ export EMAIL=\$(gcloud config get-value core/account) # to set email"| pv -qL 100
    export EMAIL=$(gcloud config get-value core/account)
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=\"serviceAccount:$GCP_PROJECT.svc.id.goog[gke-system/gke-telemetry-agent]\" --role=roles/gkemulticloud.telemetryWriter --no-user-output-enabled # to enable system container logging and container metrics" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member="serviceAccount:$GCP_PROJECT.svc.id.goog[gke-system/gke-telemetry-agent]" --role=roles/gkemulticloud.telemetryWriter --no-user-output-enabled
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=\"serviceAccount:$CLOUDBUILD_SA\" --role=\"roles/gkehub.gatewayAdmin\" --no-user-output-enabled # to enable user to access the Connect gateway API" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member="serviceAccount:$CLOUDBUILD_SA" --role="roles/gkehub.gatewayAdmin" --no-user-output-enabled
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=\"serviceAccount:$CLOUDBUILD_SA\" --role=\"roles/gkehub.viewer\" --no-user-output-enabled # to enable a user retrieve cluster kubeconfigs" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member="serviceAccount:$CLOUDBUILD_SA" --role="roles/gkehub.viewer" --no-user-output-enabled
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=\"serviceAccount:$CLOUDBUILD_SA\" --role=\"roles/container.viewer\" --no-user-output-enabled # to enable user to view GKE Clusters" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member="serviceAccount:$CLOUDBUILD_SA" --role="roles/container.viewer" --no-user-output-enabled
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=\"serviceAccount:$CLOUDBUILD_SA\" --role=\"roles/gkehub.viewer\" --no-user-output-enabled # to enable user to view clusters outside Google Cloud" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member="serviceAccount:$CLOUDBUILD_SA" --role="roles/gkehub.viewer" --no-user-output-enabled   
    case ${PLATFORM^^} in
        AWS)
            echo
            echo "$ export OIDC_URL=\$(\$PROJDIR/aws/aws eks describe-cluster --name $AWS_CLUSTER --region $AWS_REGION --query \"cluster.identity.oidc.issuer\" --output text) # to set check if provider exists" | pv -qL 100
            export OIDC_URL=$($PROJDIR/aws/aws eks describe-cluster --name $AWS_CLUSTER --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text)
            if [[ -z "$OIDC_URL" ]] ; then
                echo
                echo "$ $PROJDIR/aws/eksctl utils associate-iam-oidc-provider --cluster $AWS_CLUSTER --approve # to create an IAM OIDC identity provider" | pv -qL 100
                $PROJDIR/aws/eksctl utils associate-iam-oidc-provider --cluster $AWS_CLUSTER --approve
                echo
                echo "$ export OIDC_URL=\$(\$PROJDIR/aws/aws eks describe-cluster --name $AWS_CLUSTER --region $AWS_REGION --query \"cluster.identity.oidc.issuer\" --output text) # to set URL" | pv -qL 100
                export OIDC_URL=$($PROJDIR/aws/aws eks describe-cluster --name $AWS_CLUSTER --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text)
            fi



            echo
            echo "$ export OIDC_PROVIDER_ID=\$(echo $OIDC_URL | cut -d \"/\" -f5) # to set ID" | pv -qL 100
            export OIDC_PROVIDER_ID=$(echo $OIDC_URL | cut -d "/" -f5)

            # https://cloud.google.com/anthos/clusters/docs/multi-cloud/aws/how-to/use-workload-identity-aws
            echo
            echo "$ $PROJDIR/aws/aws iam create-open-id-connect-provider --url $OIDC_URL --client-id-list sts.amazonaws.com --thumbprint-list 08745487e891c19e3078c1f2a07e452950ef36f6 # to create an AWS IAM OIDC provider" | pv -qL 100
            $PROJDIR/aws/aws iam create-open-id-connect-provider --url $OIDC_URL --client-id-list sts.amazonaws.com --thumbprint-list 08745487e891c19e3078c1f2a07e452950ef36f6
            echo
            echo "$ export PROVIDER_ARN=\$($PROJDIR/aws/aws iam list-open-id-connect-providers --output=text --query \"OpenIDConnectProviderList[?ends_with(Arn, '\${OIDC_URL##*/}') == \\\`true\\\`].Arn\") # to get the provider's Amazon Resource Name (ARN)" | pv -qL 100
            export PROVIDER_ARN=$($PROJDIR/aws/aws iam list-open-id-connect-providers --output=text --query "OpenIDConnectProviderList[?ends_with(Arn, '${OIDC_URL##*/}') == \`true\`].Arn")
            echo
            echo "$ cat > $PROJDIR/trust-policy.json << EOF
{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Principal\": {
        \"Federated\": \"\$PROVIDER_ARN\"
      },
      \"Action\": \"sts:AssumeRoleWithWebIdentity\",
      \"Condition\": {
        \"StringEquals\": {
          \"\$ISSUER_HOST:sub\": \"system:serviceaccount:gke-system:gke-telemetry-agent\"
        }
      }
    }
  ]
}
EOF" | pv -qL 100
            cat > $PROJDIR/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "$PROVIDER_ARN"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "$ISSUER_HOST:sub": "system:serviceaccount:gke-system:gke-telemetry-agent"
        }
      }
    }
  ]
}
EOF
            echo
            echo "$ aws iam create-role --role-name=AnthosWebIdentity --assume-role-policy-document file://$PROJDIR/trust-policy.json # to create AWS IAM role" | pv -qL 100
            aws iam create-role --role-name=AnthosWebIdentity --assume-role-policy-document file://$PROJDIR/trust-policy.json
            echo
            echo "$ aws iam attach-role-policy --role-name=AnthosWebIdentity --policy-arn=arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess # to attach AWS IAM policy to the role" | pv -qL 100
            aws iam attach-role-policy --role-name=AnthosWebIdentity --policy-arn=arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess
            # https://cloud.google.com/anthos/clusters/docs/multi-cloud/aws/how-to/use-workload-identity-aws

            echo
            echo "$ export OIDC_PROVIDER=\$(\$PROJDIR/aws/aws iam list-open-id-connect-providers | grep $OIDC_PROVIDER_ID) # to check existence of provider" | pv -qL 100
            export OIDC_PROVIDER=$($PROJDIR/aws/aws iam list-open-id-connect-providers | grep $OIDC_PROVIDER_ID)
            if [[ -z "$OIDC_PROVIDER" ]] ; then
                echo
                echo "$ $PROJDIR/aws/eksctl utils associate-iam-oidc-provider --cluster $AWS_CLUSTER --approve # to create IAM OIDC identity provider" | pv -qL 100
                $PROJDIR/aws/eksctl utils associate-iam-oidc-provider --cluster $AWS_CLUSTER --approve
            fi
            echo
            echo "$ \$PROJDIR/aws/aws eks update-kubeconfig --name $AWS_CLUSTER --region $AWS_REGION # to update kubeconfig" | pv -qL 100
            $PROJDIR/aws/aws eks update-kubeconfig --name $AWS_CLUSTER --region $AWS_REGION
            echo
            echo "$ $PROJDIR/aws/eksctl utils update-cluster-logging --enable-types=all --region=$AWS_REGION --cluster=$AWS_CLUSTER --approve # to enable logging" | pv -qL 100
            $PROJDIR/aws/eksctl utils update-cluster-logging --enable-types=all --region=$AWS_REGION --cluster=$AWS_CLUSTER --approve
            echo


            echo
            echo "$ $PROJDIR/kubectx eks # to switch context" | pv -qL 100
            $PROJDIR/kubectx eks
            echo
            echo "$ gcloud container attached clusters register $AWS_CLUSTER --location=$GCP_REGION --fleet-project=$GCP_PROJECT --platform-version=1.29.0-gke.1 --distribution=eks --issuer-url=$OIDC_URL --context=$(kubectl config current-context) --admin-users=$(gcloud config get-value core/account) --kubeconfig=~/.kube/config --description=$AWS_CLUSTER --logging=SYSTEM,WORKLOAD # to register cluster" | pv -qL 100
            gcloud container attached clusters register $AWS_CLUSTER --location=$GCP_REGION --fleet-project=$GCP_PROJECT --platform-version=1.29.0-gke.1 --distribution=eks --issuer-url=$OIDC_URL --context=$(kubectl config current-context) --admin-users=$(gcloud config get-value core/account) --kubeconfig=~/.kube/config --description=$AWS_CLUSTER --logging=SYSTEM,WORKLOAD 
            echo
            echo "$ gcloud beta container fleet memberships generate-gateway-rbac --membership=$AWS_CLUSTER --role=clusterrole/cluster-admin --users=$CLOUDBUILD_SA --project=$GCP_PROJECT --context $(kubectl config current-context) --kubeconfig $HOME/.kube/config --apply # to enable clusters to authorize requests from cloud build" | pv -qL 100
            gcloud beta container fleet memberships generate-gateway-rbac --membership=$AWS_CLUSTER --role=clusterrole/cluster-admin --users=$CLOUDBUILD_SA --project=$GCP_PROJECT --context $(kubectl config current-context) --kubeconfig $HOME/.kube/config --apply
        ;;
        AZURE)
            echo
            echo "$ /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP # to retrieve cluster credentials" | pv -qL 100
            /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP
            echo
            echo "$ $PROJDIR/kubectx aks # to switch context" | pv -qL 100
            $PROJDIR/kubectx aks
            echo
            echo "$ gcloud container attached clusters register $AZURE_CLUSTER  --location=$GCP_REGION --fleet-project=$GCP_PROJECT --platform-version=1.29.0-gke.1 --distribution=aks --context=$(kubectl config current-context) --has-private-issuer --admin-users=$(gcloud config get-value core/account) --kubeconfig=~/.kube/config --logging=SYSTEM,WORKLOAD # enable logging" | pv -qL 100
            gcloud container attached clusters register $AZURE_CLUSTER  --location=$GCP_REGION --fleet-project=$GCP_PROJECT --platform-version=1.29.0-gke.1 --distribution=aks --context=$(kubectl config current-context) --has-private-issuer --admin-users=$(gcloud config get-value core/account) --kubeconfig=~/.kube/config --logging=SYSTEM,WORKLOAD 
            echo
            echo "$ gcloud beta container fleet memberships generate-gateway-rbac --membership=$AZURE_CLUSTER --role=clusterrole/cluster-admin --users=$CLOUDBUILD_SA --project=$GCP_PROJECT --context $(kubectl config current-context) --kubeconfig $HOME/.kube/config --apply # to enable clusters to authorize requests from cloud build" | pv -qL 100
            gcloud beta container fleet memberships generate-gateway-rbac --membership=$AZURE_CLUSTER --role=clusterrole/cluster-admin --users=$CLOUDBUILD_SA --project=$GCP_PROJECT --context $(kubectl config current-context) --kubeconfig $HOME/.kube/config --apply
        ;;
        GCP)
            echo
            echo "$ gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
            gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE
            echo
            echo "$ $PROJDIR/kubectx gke # to switch context" | pv -qL 100
            $PROJDIR/kubectx gke
            echo
            echo "$ gcloud container fleet memberships register $GCP_CLUSTER --gke-cluster=$GCP_ZONE/$GCP_CLUSTER --enable-workload-identity # to register cluster" | pv -qL 100
            gcloud container fleet memberships register $GCP_CLUSTER --gke-cluster=$GCP_ZONE/$GCP_CLUSTER --enable-workload-identity
            echo
            echo "$ gcloud container hub memberships get-credentials $GCP_CLUSTER # to set context" | pv -qL 100
            gcloud container hub memberships get-credentials $GCP_CLUSTER
            echo
            echo "$ $PROJDIR/kubectx gke # to switch context" | pv -qL 100
            $PROJDIR/kubectx gke
            echo
            echo "$ gcloud beta container fleet memberships generate-gateway-rbac --membership=$GCP_CLUSTER --role=clusterrole/cluster-admin --users=$EMAIL --project=$GCP_PROJECT --context $(kubectl config current-context) --kubeconfig $HOME/.kube/config --apply # to enable clusters to authorize requests from Google Cloud console" | pv -qL 100
            gcloud beta container fleet memberships generate-gateway-rbac --membership=$GCP_CLUSTER --role=clusterrole/cluster-admin --users=$EMAIL --project=$GCP_PROJECT --context $(kubectl config current-context) --kubeconfig $HOME/.kube/config --apply
            echo
            echo "$ gcloud beta container fleet memberships generate-gateway-rbac --membership=$GCP_CLUSTER --role=clusterrole/cluster-admin --users=$CLOUDBUILD_SA --project=$GCP_PROJECT --context $(kubectl config current-context) --kubeconfig $HOME/.kube/config --apply # to enable clusters to authorize requests from cloud build" | pv -qL 100
            gcloud beta container fleet memberships generate-gateway-rbac --membership=$GCP_CLUSTER --role=clusterrole/cluster-admin --users=$CLOUDBUILD_SA --project=$GCP_PROJECT --context $(kubectl config current-context) --kubeconfig $HOME/.kube/config --apply
        ;;
    esac
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},6x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    case ${PLATFORM^^} in
        AWS)
            echo
            echo "$ \$PROJDIR/aws/aws eks update-kubeconfig --name $AWS_CLUSTER --region $AWS_REGION # to update kubeconfig" | pv -qL 100
            $PROJDIR/aws/aws eks update-kubeconfig --name $AWS_CLUSTER --region $AWS_REGION
            echo
            echo "$ $PROJDIR/kubectx eks=. # to switch context" | pv -qL 100
            $PROJDIR/kubectx eks=.
            echo
            echo "$ gcloud container hub memberships unregister $AWS_CLUSTER --context=eks # to unregister cluster" | pv -qL 100
            gcloud container hub memberships unregister $AWS_CLUSTER --context=eks
            echo
            echo "$ gcloud container attached clusters delete $AWS_CLUSTER --location=$GCP_REGION --ignore-errors --allow-missing # to unregister cluster" | pv -qL 100
            gcloud container attached clusters delete $AWS_CLUSTER --location=$GCP_REGION --ignore-errors --allow-missing  
        ;;
        AZURE)
            echo
            echo "$ /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP # to retrieve cluster credentials" | pv -qL 100
            /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP
            echo
            echo "$ $PROJDIR/kubectx aks=. # to switch context" | pv -qL 100
            $PROJDIR/kubectx aks=.
            echo
            echo "$ gcloud container hub memberships unregister $AZURE_CLUSTER --context=aks # to register cluster" | pv -qL 100
            gcloud container hub memberships unregister $AZURE_CLUSTER --context=aks
            echo
            echo "$ gcloud container attached clusters delete $AZURE_CLUSTER --location=$GCP_REGION --ignore-errors --allow-missing # to delete cluster" | pv -qL 100
            gcloud container attached clusters delete $AZURE_CLUSTER --location=$GCP_REGION --ignore-errors --allow-missing
        ;;
        GCP)
            echo
            echo "$ gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
            gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE
            echo
            echo "$ $PROJDIR/kubectx gke=. # to switch context" | pv -qL 100
            $PROJDIR/kubectx gke=.
            echo
            echo "$ gcloud container fleet memberships unregister $GCP_CLUSTER --context=gke # to unregister cluster" | pv -qL 100
            gcloud container fleet memberships unregister $GCP_CLUSTER --gke-cluster=$GCP_ZONE/$GCP_CLUSTER
        ;;
    esac
else
    export STEP="${STEP},6i"
    echo
    echo "1. Register cluster to fleet" | pv -qL 100
    echo "2. Grant cluster admin priviledges to cloud build service account" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"-7")
start=`date +%s`
source $ENVDIR/.env
case ${PLATFORM^^} in
    AWS)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},7i"
            echo
            echo "$ \$PROJDIR/aws/aws eks update-kubeconfig --name \$AWS_CLUSTER --region \$AWS_REGION # to update kubeconfig" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx eks # to switch context" | pv -qL 100
            echo
            echo "$ gcloud iam service-accounts create anthos-lm-forwarder # to create service account" | pv -qL 100
            echo
            echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=\"serviceAccount:anthos-lm-forwarder@\${GCP_PROJECT}.iam.gserviceaccount.com\" --role=roles/logging.logWriter --no-user-output-enabled # to set permissions to write logs to Cloud Logging APIs" | pv -qL 100
            echo
            echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=\"serviceAccount:anthos-lm-forwarder@\${GCP_PROJECT}.iam.gserviceaccount.com\" --role=roles/monitoring.metricWriter --no-user-output-enabled # to set permissions to write metrics to Cloud Monitoring APIs" | pv -qL 100
            echo
            echo "$ gcloud iam service-accounts keys create \$PROJDIR/credentials.json --iam-account anthos-lm-forwarder@\${GCP_PROJECT}.iam.gserviceaccount.com # to download key" | pv -qL 100
            echo
            echo "$ kubectl create secret generic google-cloud-credentials -n kube-system --from-file \$PROJDIR/credentials.json # to configure secret" | pv -qL 100
            echo
            echo "$ kubectl apply -f \$PROJDIR/aggregator.yaml # to apply yaml" | pv -qL 100
            echo
            echo "$ kubectl apply -f \$PROJDIR/attached-logging-monitoring/logging/forwarder.yaml # to apply yaml" | pv -qL 100
            echo
            echo "$ kubectl apply -f \$PROJDIR/prometheus.yaml # to apply yaml" | pv -qL 100
            echo
            echo "$ kubectl apply -f \$PROJDIR/aggregator.yaml # to apply yaml" | pv -qL 100
            echo
            echo "$ kubectl apply -f \$PROJDIR/attached-logging-monitoring/monitoring/server-configmap.yaml # to apply yaml" | pv -qL 100
            echo
            echo "$ kubectl apply -f \$PROJDIR/attached-logging-monitoring/monitoring/sidecar-configmap.yaml # to apply yaml" | pv -qL 100
        elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},7"
            echo
            echo "$ \$PROJDIR/aws/aws eks update-kubeconfig --name $AWS_CLUSTER --region $AWS_REGION # to update kubeconfig" | pv -qL 100
            $PROJDIR/aws/aws eks update-kubeconfig --name $AWS_CLUSTER --region $AWS_REGION
            echo
            echo "$ $PROJDIR/kubectx eks # to switch context" | pv -qL 100
            $PROJDIR/kubectx eks
            echo
            echo "$ curl https://raw.githubusercontent.com/shamimice03/AWS_EKS-EBS_CSI/main/AwsEBSCSIDriverPolicy.json > $PROJDIR/ebs_csi_policy.json # to create policy file" | pv -qL 100
            curl https://raw.githubusercontent.com/shamimice03/AWS_EKS-EBS_CSI/main/AwsEBSCSIDriverPolicy.json > $PROJDIR/ebs_csi_policy.json
            echo
            echo "$ export POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`AwsEBSCSIDriverPolicy`].Arn' --output text) # to create extract POLICY_ARN" | pv -qL 100
            export POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`AwsEBSCSIDriverPolicy`].Arn' --output text)
            if [[ -z $POLICY_ARN ]]; then
                echo
                echo "$ aws iam create-policy --policy-name AwsEBSCSIDriverPolicy --policy-document file://$PROJDIR/ebs_csi_policy.json # to create IAM-POLICY" | pv -qL 100
                aws iam create-policy --policy-name AwsEBSCSIDriverPolicy --policy-document file://$PROJDIR/ebs_csi_policy.json # to create IAM-POLICY
            fi
            echo
            echo "$ export ROLE_ARN=\$(echo \"\${POLICY_ARN}\" | cut -d':' -f1-5) # to extract role" | pv -qL 100
            export ROLE_ARN=$(echo "${POLICY_ARN}" | cut -d':' -f1-5):role/AmazonEKS_EBS_CSI_DriverRole
            echo
            echo "$ $PROJDIR/aws/eksctl create addon --name aws-ebs-csi-driver --cluster $AWS_CLUSTER --service-account-role-arn $ROLE_ARN --force # to configure IAM Role for Service Account" | pv -qL 100
            $PROJDIR/aws/eksctl create addon --name aws-ebs-csi-driver --cluster $AWS_CLUSTER --service-account-role-arn $ROLE_ARN --force
            echo
            gcloud iam service-accounts delete anthos-lm-forwarder@$GCP_PROJECT.iam.gserviceaccount.com --quiet > /dev/null 2>&1
            echo "$ gcloud iam service-accounts create anthos-lm-forwarder # to create service account" | pv -qL 100
            gcloud iam service-accounts create anthos-lm-forwarder
            echo
            echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=\"serviceAccount:anthos-lm-forwarder@${GCP_PROJECT}.iam.gserviceaccount.com\" --role=roles/logging.logWriter --no-user-output-enabled # to set permissions to write logs to Cloud Logging APIs" | pv -qL 100
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member="serviceAccount:anthos-lm-forwarder@${GCP_PROJECT}.iam.gserviceaccount.com" --role=roles/logging.logWriter --no-user-output-enabled
            echo
            echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=\"serviceAccount:anthos-lm-forwarder@${GCP_PROJECT}.iam.gserviceaccount.com\" --role=roles/monitoring.metricWriter --no-user-output-enabled # to set permissions to write metrics to Cloud Monitoring APIs" | pv -qL 100
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member="serviceAccount:anthos-lm-forwarder@${GCP_PROJECT}.iam.gserviceaccount.com" --role=roles/monitoring.metricWriter --no-user-output-enabled
            echo
            echo "$ gcloud iam service-accounts keys create $PROJDIR/credentials.json --iam-account anthos-lm-forwarder@${GCP_PROJECT}.iam.gserviceaccount.com # to download key" | pv -qL 100
            gcloud iam service-accounts keys create $PROJDIR/credentials.json --iam-account anthos-lm-forwarder@${GCP_PROJECT}.iam.gserviceaccount.com
            echo
            kubectl delete secret google-cloud-credentials -n kube-system > /dev/null 2>&1
            echo "$ kubectl create secret generic google-cloud-credentials -n kube-system --from-file $PROJDIR/credentials.json # to configure secret" | pv -qL 100
            kubectl create secret generic google-cloud-credentials -n kube-system --from-file $PROJDIR/credentials.json
            echo
            echo "$ sed 's/\[PROJECT_ID\]/'$GCP_PROJECT'/g' $PROJDIR/attached-logging-monitoring/logging/aggregator.yaml > $PROJDIR/aggregator.yaml # to customise yaml file" | pv -qL 100
            sed 's/\[PROJECT_ID\]/'$GCP_PROJECT'/g' $PROJDIR/attached-logging-monitoring/logging/aggregator.yaml > $PROJDIR/aggregator.yaml
            echo
            echo "$ sed -i 's/\[CLUSTER_NAME\]/'$AWS_CLUSTER'/g' $PROJDIR/aggregator.yaml # to customise yaml file" | pv -qL 100
            sed -i 's/\[CLUSTER_NAME\]/'$AWS_CLUSTER'/g' $PROJDIR/aggregator.yaml
            echo
            echo "$ sed -i 's/\[CLUSTER_LOCATION\]/global/g' $PROJDIR/aggregator.yaml # to customise yaml file" | pv -qL 100
            sed -i 's/\[CLUSTER_LOCATION\]/global/g' $PROJDIR/aggregator.yaml
            echo
            echo "$ sed -i 's/#\ storageClassName:\ gp2\ #AWS\ EKS/storageClassName:\ gp2/g' $PROJDIR/aggregator.yaml # to customise yaml file" | pv -qL 100
            sed -i 's/#\ storageClassName:\ gp2\ #AWS\ EKS/storageClassName:\ gp2/g' $PROJDIR/aggregator.yaml
            echo
            echo "$ kubectl apply -f $PROJDIR/aggregator.yaml # to apply yaml" | pv -qL 100
            kubectl apply -f $PROJDIR/aggregator.yaml
            echo
            echo "$ kubectl apply -f $PROJDIR/attached-logging-monitoring/logging/forwarder.yaml # to apply yaml" | pv -qL 100
            kubectl apply -f $PROJDIR/attached-logging-monitoring/logging/forwarder.yaml
            echo
            echo "$ sed 's/\[PROJECT_ID\]/'$GCP_PROJECT'/g' $PROJDIR/attached-logging-monitoring/monitoring/prometheus.yaml > $PROJDIR/prometheus.yaml # to customise yaml file" | pv -qL 100
            sed 's/\[PROJECT_ID\]/'$GCP_PROJECT'/g' $PROJDIR/attached-logging-monitoring/monitoring/prometheus.yaml > $PROJDIR/prometheus.yaml
            echo
            echo "$ sed -i 's/\[CLUSTER_NAME\]/'$AWS_CLUSTER'/g' $PROJDIR/prometheus.yaml # to customise yaml file" | pv -qL 100
            sed -i 's/\[CLUSTER_NAME\]/'$AWS_CLUSTER'/g' $PROJDIR/prometheus.yaml
            echo
            echo "$ sed -i 's/\[CLUSTER_LOCATION\]/global/g' $PROJDIR/prometheus.yaml # to customise yaml file" | pv -qL 100
            sed -i 's/\[CLUSTER_LOCATION\]/global/g' $PROJDIR/prometheus.yaml
            echo
            echo "$ sed -i 's/#\ storageClassName:\ gp2\ #AWS\ EKS/storageClassName:\ gp2/g' $PROJDIR/prometheus.yaml # to customise yaml file" | pv -qL 100
            sed -i 's/#\ storageClassName:\ gp2\ #AWS\ EKS/storageClassName:\ gp2/g' $PROJDIR/prometheus.yaml
            echo
            echo "$ kubectl apply -f $PROJDIR/prometheus.yaml # to apply yaml" | pv -qL 100
            kubectl apply -f $PROJDIR/prometheus.yaml
            echo
            echo "$ kubectl apply -f $PROJDIR/aggregator.yaml # to apply yaml" | pv -qL 100
            kubectl apply -f $PROJDIR/aggregator.yaml
            echo
            echo "$ kubectl apply -f $PROJDIR/attached-logging-monitoring/monitoring/server-configmap.yaml # to apply yaml" | pv -qL 100
            kubectl apply -f $PROJDIR/attached-logging-monitoring/monitoring/server-configmap.yaml
            echo
            echo "$ kubectl apply -f $PROJDIR/attached-logging-monitoring/monitoring/sidecar-configmap.yaml # to apply yaml" | pv -qL 100
            kubectl apply -f $PROJDIR/attached-logging-monitoring/monitoring/sidecar-configmap.yaml
            echo
            echo "$ kubectl create -f https://raw.githubusercontent.com/shamimice03/AWS_EKS-EBS_CSI/main/Demo-storageClass.yaml # to create Storage Class using EBS CSI Provision" | pv -qL 100
            kubectl create -f https://raw.githubusercontent.com/shamimice03/AWS_EKS-EBS_CSI/main/Demo-storageClass.yaml
            echo
            echo "$ kubectl create -f https://raw.githubusercontent.com/shamimice03/AWS_EKS-EBS_CSI/main/pvc-pod.yaml # to create a Persistent Volume Claim (PVC) and attach the PVC as a volume into a pod" | pv -qL 100
            kubectl create -f https://raw.githubusercontent.com/shamimice03/AWS_EKS-EBS_CSI/main/pvc-pod.yaml
            echo
            echo "$ export OIDC_URL=\$(\$PROJDIR/aws/aws eks describe-cluster --name $AWS_CLUSTER --region $AWS_REGION --query \"cluster.identity.oidc.issuer\" --output text) # to set check if provider exists" | pv -qL 100
            export OIDC_URL=$($PROJDIR/aws/aws eks describe-cluster --name $AWS_CLUSTER --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text)
        elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},7x"
            echo
            echo "$ \$PROJDIR/aws/aws eks update-kubeconfig --name $AWS_CLUSTER --region $AWS_REGION # to update kubeconfig" | pv -qL 100
            $PROJDIR/aws/aws eks update-kubeconfig --name $AWS_CLUSTER --region $AWS_REGION
            echo
            echo "$ $PROJDIR/kubectx eks # to switch context" | pv -qL 100
            $PROJDIR/kubectx eks
            echo
            echo "$ kubectl delete -f $PROJDIR/attached-logging-monitoring/logging # delete yaml" | pv -qL 100
            kubectl delete -f $PROJDIR/attached-logging-monitoring/logging
            echo
            echo "$ kubectl delete -f $PROJDIR/attached-logging-monitoring/monitoring # delete yaml" | pv -qL 100
            kubectl delete -f $PROJDIR/attached-logging-monitoring/monitoring
            echo
            echo "$ kubectl delete secret google-cloud-credentials -n kube-system # to delete secret" | pv -qL 100
            kubectl delete secret google-cloud-credentials -n kube-system
            echo
            echo "$ rm -r $PROJDIR/credentials.json # to delete key" | pv -qL 100
            rm -r $PROJDIR/credentials.json
            echo
            echo "$ gcloud iam service-accounts delete anthos-lm-forwarder@$GCP_PROJECT.iam.gserviceaccount.com --quiet # to delete service account" | pv -qL 100
            gcloud iam service-accounts delete anthos-lm-forwarder@$GCP_PROJECT.iam.gserviceaccount.com --quiet
        fi
    ;;
    AZURE)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},7i"
            echo
            echo "$ /usr/bin/az aks get-credentials -n \$AZURE_CLUSTER -g \$AZ_RESOURCEGROUP # to retrieve cluster credentials" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx aks # to switch context" | pv -qL 100
            echo
            echo "$ gcloud iam service-accounts create anthos-lm-forwarder # to create service account" | pv -qL 100
            echo
            echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=\"serviceAccount:anthos-lm-forwarder@\${GCP_PROJECT}.iam.gserviceaccount.com\" --role=roles/logging.logWriter --no-user-output-enabled # to set permissions to write logs to Cloud Logging APIs" | pv -qL 100
            echo
            echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=\"serviceAccount:anthos-lm-forwarder@\${GCP_PROJECT}.iam.gserviceaccount.com\" --role=roles/monitoring.metricWriter --no-user-output-enabled # to set permissions to write metrics to Cloud Monitoring APIs" | pv -qL 100
            echo
            echo "$ gcloud iam service-accounts keys create \$PROJDIR/credentials.json --iam-account anthos-lm-forwarder@\${GCP_PROJECT}.iam.gserviceaccount.com # to download key" | pv -qL 100
            echo
            echo "$ kubectl create secret generic google-cloud-credentials -n kube-system --from-file \$PROJDIR/credentials.json # to configure secret" | pv -qL 100
            echo
            echo "$ kubectl apply -f \$PROJDIR/aggregator.yaml # to apply yaml" | pv -qL 100
            echo
            echo "$ kubectl apply -f \$PROJDIR/attached-logging-monitoring/logging/forwarder.yaml # to apply yaml" | pv -qL 100
            echo
            echo "$ kubectl apply -f \$PROJDIR/prometheus.yaml # to apply yaml" | pv -qL 100
            echo
            echo "$ kubectl apply -f \$PROJDIR/aggregator.yaml # to apply yaml" | pv -qL 100
            echo
            echo "$ kubectl apply -f \$PROJDIR/attached-logging-monitoring/monitoring/server-configmap.yaml # to apply yaml" | pv -qL 100
            echo
            echo "$ kubectl apply -f \$PROJDIR/attached-logging-monitoring/monitoring/sidecar-configmap.yaml # to apply yaml" | pv -qL 100
            echo
            echo "$ gcloud container hub memberships unregister \$AZURE_CLUSTER --context=aks # to register cluster" | pv -qL 100
        elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},7"
            echo
            echo "$ /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP # to retrieve cluster credentials" | pv -qL 100
            /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP
            echo
            echo "$ $PROJDIR/kubectx aks # to switch context" | pv -qL 100
            $PROJDIR/kubectx aks
            echo
            gcloud iam service-accounts delete anthos-lm-forwarder@$GCP_PROJECT.iam.gserviceaccount.com --quiet > /dev/null 2>&1
            echo "$ gcloud iam service-accounts create anthos-lm-forwarder # to create service account" | pv -qL 100
            gcloud iam service-accounts create anthos-lm-forwarder
            echo
            echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=\"serviceAccount:anthos-lm-forwarder@${GCP_PROJECT}.iam.gserviceaccount.com\" --role=roles/logging.logWriter --no-user-output-enabled # to set permissions to write logs to Cloud Logging APIs" | pv -qL 100
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member="serviceAccount:anthos-lm-forwarder@${GCP_PROJECT}.iam.gserviceaccount.com" --role=roles/logging.logWriter --no-user-output-enabled
            echo
            echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=\"serviceAccount:anthos-lm-forwarder@${GCP_PROJECT}.iam.gserviceaccount.com\" --role=roles/monitoring.metricWriter --no-user-output-enabled # to set permissions to write metrics to Cloud Monitoring APIs" | pv -qL 100
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member="serviceAccount:anthos-lm-forwarder@${GCP_PROJECT}.iam.gserviceaccount.com" --role=roles/monitoring.metricWriter --no-user-output-enabled
            echo
            echo "$ gcloud iam service-accounts keys create $PROJDIR/credentials.json --iam-account anthos-lm-forwarder@${GCP_PROJECT}.iam.gserviceaccount.com # to download key" | pv -qL 100
            gcloud iam service-accounts keys create $PROJDIR/credentials.json --iam-account anthos-lm-forwarder@${GCP_PROJECT}.iam.gserviceaccount.com
            echo
            kubectl delete secret google-cloud-credentials -n kube-system > /dev/null 2>&1
            echo "$ kubectl create secret generic google-cloud-credentials -n kube-system --from-file $PROJDIR/credentials.json # to configure secret" | pv -qL 100
            kubectl create secret generic google-cloud-credentials -n kube-system --from-file $PROJDIR/credentials.json
            echo
            echo "$ sed 's/\[PROJECT_ID\]/'$GCP_PROJECT'/g' $PROJDIR/attached-logging-monitoring/logging/aggregator.yaml > $PROJDIR/aggregator.yaml # to customise yaml file" | pv -qL 100
            sed 's/\[PROJECT_ID\]/'$GCP_PROJECT'/g' $PROJDIR/attached-logging-monitoring/logging/aggregator.yaml > $PROJDIR/aggregator.yaml
            echo
            echo "$ sed -i 's/\[CLUSTER_NAME\]/'$AZURE_CLUSTER'/g' $PROJDIR/aggregator.yaml # to customise yaml file" | pv -qL 100
            sed -i 's/\[CLUSTER_NAME\]/'$AZURE_CLUSTER'/g' $PROJDIR/aggregator.yaml
            echo
            echo "$ sed -i 's/\[CLUSTER_LOCATION\]/global/g' $PROJDIR/aggregator.yaml # to customise yaml file" | pv -qL 100
            sed -i 's/\[CLUSTER_LOCATION\]/global/g' $PROJDIR/aggregator.yaml
            echo
            echo "$ sed -i 's/#\ storageClassName:\ default\ #Azure\ AKS/storageClassName:\ default/g' $PROJDIR/aggregator.yaml # to customise yaml file" | pv -qL 100
            sed -i 's/#\ storageClassName:\ default\ #Azure\ AKS/storageClassName:\ default/g' $PROJDIR/aggregator.yaml
            echo
            echo "$ kubectl apply -f $PROJDIR/aggregator.yaml # to apply yaml" | pv -qL 100
            kubectl apply -f $PROJDIR/aggregator.yaml
            echo
            echo "$ kubectl apply -f $PROJDIR/attached-logging-monitoring/logging/forwarder.yaml # to apply yaml" | pv -qL 100
            kubectl apply -f $PROJDIR/attached-logging-monitoring/logging/forwarder.yaml
            echo
            echo "$ sed 's/\[PROJECT_ID\]/'$GCP_PROJECT'/g' $PROJDIR/attached-logging-monitoring/monitoring/prometheus.yaml > $PROJDIR/prometheus.yaml # to customise yaml file" | pv -qL 100
            sed 's/\[PROJECT_ID\]/'$GCP_PROJECT'/g' $PROJDIR/attached-logging-monitoring/monitoring/prometheus.yaml > $PROJDIR/prometheus.yaml
            echo
            echo "$ sed -i 's/\[CLUSTER_NAME\]/'$AZURE_CLUSTER'/g' $PROJDIR/prometheus.yaml # to customise yaml file" | pv -qL 100
            sed -i 's/\[CLUSTER_NAME\]/'$AZURE_CLUSTER'/g' $PROJDIR/prometheus.yaml
            echo
            echo "$ sed -i 's/\[CLUSTER_LOCATION\]/global/g' $PROJDIR/prometheus.yaml # to customise yaml file" | pv -qL 100
            sed -i 's/\[CLUSTER_LOCATION\]/global/g' $PROJDIR/prometheus.yaml
            echo
            echo "$ sed -i 's/#\ storageClassName:\ default\ #Azure\ AKS/storageClassName:\ default/g' $PROJDIR/prometheus.yaml # to customise yaml file" | pv -qL 100
            sed -i 's/#\ storageClassName:\ default\ #Azure\ AKS/storageClassName:\ default/g' $PROJDIR/prometheus.yaml
            echo
            echo "$ kubectl apply -f $PROJDIR/prometheus.yaml # to apply yaml" | pv -qL 100
            kubectl apply -f $PROJDIR/prometheus.yaml
            echo
            echo "$ kubectl apply -f $PROJDIR/aggregator.yaml # to apply yaml" | pv -qL 100
            kubectl apply -f $PROJDIR/aggregator.yaml
            echo
            echo "$ kubectl apply -f $PROJDIR/attached-logging-monitoring/monitoring/server-configmap.yaml # to apply yaml" | pv -qL 100
            kubectl apply -f $PROJDIR/attached-logging-monitoring/monitoring/server-configmap.yaml
            echo
            echo "$ kubectl apply -f $PROJDIR/attached-logging-monitoring/monitoring/sidecar-configmap.yaml # to apply yaml" | pv -qL 100
            kubectl apply -f $PROJDIR/attached-logging-monitoring/monitoring/sidecar-configmap.yaml
        elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},7x"
            echo
            echo "$ /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP # to retrieve cluster credentials" | pv -qL 100
            /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP
            echo
            echo "$ $PROJDIR/kubectx aks # to switch context" | pv -qL 100
            $PROJDIR/kubectx aks
            echo
            echo "$ kubectl delete -f $PROJDIR/attached-logging-monitoring/logging # delete yaml" | pv -qL 100
            kubectl delete -f $PROJDIR/attached-logging-monitoring/logging
            echo
            echo "$ kubectl delete -f $PROJDIR/attached-logging-monitoring/monitoring # delete yaml" | pv -qL 100
            kubectl delete -f $PROJDIR/attached-logging-monitoring/monitoring
            echo
            echo "$ kubectl delete secret google-cloud-credentials -n kube-system # to delete secret" | pv -qL 100
            kubectl delete secret google-cloud-credentials -n kube-system
            echo
            echo "$ rm -r $PROJDIR/credentials.json # to delete key" | pv -qL 100
            rm -r $PROJDIR/credentials.json
            echo
            echo "$ gcloud iam service-accounts delete anthos-lm-forwarder@$GCP_PROJECT.iam.gserviceaccount.com --quiet # to delete service account" | pv -qL 100
            gcloud iam service-accounts delete anthos-lm-forwarder@$GCP_PROJECT.iam.gserviceaccount.com --quiet
        fi
    ;;
    GCP)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},7i"
            echo 
            echo "*** Not Required ***" | pv -qL 100
        elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},7"
            echo 
            echo "*** Not Required ***" | pv -qL 100
        elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},7x"
            echo 
            echo "*** Nothing to delete ***" | pv -qL 100
        fi
    ;;
esac
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"7")
start=`date +%s`
source $ENVDIR/.env
case ${PLATFORM^^} in
    GCP)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},7i"
            echo
            echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=serviceAccount:\$DEVELOPER_SA --role=roles/artifactregistry.reader --no-user-output-enabled # to pull containers" | pv -qL 100
            echo
            echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=serviceAccount:\$DEVELOPER_SA --role=roles/container.developer --no-user-output-enabled # to deploy to GKE" | pv -qL 100
            echo
            echo "$ gcloud --project=\$GCP_PROJECT -q iam service-accounts add-iam-policy-binding \$DEVELOPER_SA --member=serviceAccount:\$CLOUDBUILD_SA --role=roles/iam.serviceAccountUser --no-user-output-enabled # to invoke build operations" | pv -qL 100
          elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},7"
            PROJECT_NUMBER=$(gcloud --project $GCP_PROJECT projects describe $GCP_PROJECT --format="value(projectNumber)")
            DEVELOPER_SA=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com
            CLOUDBUILD_SA=${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
            echo
            echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$DEVELOPER_SA --role=roles/artifactregistry.reader --no-user-output-enabled # to pull containers" | pv -qL 100
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$DEVELOPER_SA --role=roles/artifactregistry.reader --no-user-output-enabled
            echo
            echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$DEVELOPER_SA --role=roles/container.developer --no-user-output-enabled # to deploy to GKE" | pv -qL 100
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$DEVELOPER_SA --role=roles/container.developer --no-user-output-enabled
            echo
            echo "$ gcloud --project=$GCP_PROJECT -q iam service-accounts add-iam-policy-binding $DEVELOPER_SA --member=serviceAccount:$CLOUDBUILD_SA --role=roles/iam.serviceAccountUser --no-user-output-enabled # to invoke build operations" | pv -qL 100
            gcloud --project=$GCP_PROJECT -q iam service-accounts add-iam-policy-binding $DEVELOPER_SA --member=serviceAccount:$CLOUDBUILD_SA --role=roles/iam.serviceAccountUser --no-user-output-enabled
       elif [ $MODE -eq 3 ]; then
            export STEP="${STEP},7x"
            echo
            echo "*** Nothing to delete ***" | pv -qL 100
        else
            export STEP="${STEP},7i"
            echo
            echo "1. Configure IAM policies" | pv -qL 100
            echo "2. Configure image pull secret" | pv -qL 100
        fi
    ;;
    *)
        if [ $MODE -eq 1 ]; then
            echo
            echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=serviceAccount:\$DEVELOPER_SA --role=roles/artifactregistry.reader --no-user-output-enabled # to pull containers" | pv -qL 100
            echo
            echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=serviceAccount:\$DEVELOPER_SA --role=roles/container.developer --no-user-output-enabled # to deploy to GKE" | pv -qL 100
            echo
            echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=serviceAccount:\$DEVELOPER_SA --role=roles/gkehub.gatewayReader --no-user-output-enabled # to access connect gateway" | pv -qL 100
            echo
            echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=serviceAccount:\$DEVELOPER_SA --role=roles/gkehub.viewer --no-user-output-enabled # to retrieve credentials" | pv -qL 100
            echo
            echo "$ gcloud --project=\$GCP_PROJECT -q iam service-accounts add-iam-policy-binding \$DEVELOPER_SA --member=serviceAccount:\$CLOUDBUILD_SA --role=roles/iam.serviceAccountUser # to invoke build operations" | pv -qL 100
            echo
            echo "$ gcloud iam service-accounts keys create \$ENVDIR/image-pull.json --iam-account \$DEVELOPER_SA # to download service account key" | pv -qL 100
        elif [ $MODE -eq 2 ]; then
            PROJECT_NUMBER=$(gcloud --project $GCP_PROJECT projects describe $GCP_PROJECT --format="value(projectNumber)")
            DEVELOPER_SA=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com
            CLOUDBUILD_SA=${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
            echo
            echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$DEVELOPER_SA --role=roles/artifactregistry.reader --no-user-output-enabled # to pull containers" | pv -qL 100
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$DEVELOPER_SA --role=roles/artifactregistry.reader --no-user-output-enabled
            echo
            echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$DEVELOPER_SA --role=roles/container.developer --no-user-output-enabled # to deploy to GKE" | pv -qL 100
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$DEVELOPER_SA --role=roles/container.developer --no-user-output-enabled
            echo
            echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$DEVELOPER_SA --role=roles/gkehub.gatewayReader --no-user-output-enabled # to access connect gateway" | pv -qL 100
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$DEVELOPER_SA --role=roles/gkehub.gatewayReader --no-user-output-enabled
            echo
            echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$DEVELOPER_SA --role=roles/gkehub.viewer --no-user-output-enabled # to retrieve credentials" | pv -qL 100
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:$DEVELOPER_SA --role=roles/gkehub.viewer --no-user-output-enabled
            echo
            echo "$ gcloud --project=$GCP_PROJECT -q iam service-accounts add-iam-policy-binding $DEVELOPER_SA --member=serviceAccount:$CLOUDBUILD_SA --role=roles/iam.serviceAccountUser --no-user-output-enabled # to invoke build operations" | pv -qL 100
            gcloud --project=$GCP_PROJECT -q iam service-accounts add-iam-policy-binding $DEVELOPER_SA --member=serviceAccount:$CLOUDBUILD_SA --role=roles/iam.serviceAccountUser --no-user-output-enabled
            if [[ ! -f $ENVDIR/image-pull.json ]]; then
                echo
                echo "$ gcloud iam service-accounts keys create $ENVDIR/image-pull.json --iam-account $DEVELOPER_SA # to download service account key" | pv -qL 100
                gcloud iam service-accounts keys create $ENVDIR/image-pull.json --iam-account $DEVELOPER_SA
            fi
        fi
    ;;
esac
case ${PLATFORM^^} in
    AWS)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},7i"
            echo
            echo "$ \$PROJDIR/kubectx eks # to set context" | pv -qL 100
            echo
            echo "$ kubectl create secret docker-registry artifact-registry --docker-server=https://\${GCP_REGION}-docker.pkg.dev --docker-email=\$EMAIL --docker-username=_json_key --docker-password=\"\$(cat $ENVDIR/image-pull.json)\" # to create docker registry secret" | pv -qL 100
            echo
            echo "$ kubectl patch serviceaccount default -p '{\"imagePullSecrets\": [{\"name\": \"artifact-registry\"}]}' # to patch the default k8s service account with docker-registry image pull secret" | pv -qL 100
         elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},7"
            echo
            echo "$ $PROJDIR/kubectx eks # to set context" | pv -qL 100
            $PROJDIR/kubectx eks
            echo
            export EMAIL=$(gcloud config get-value core/account) > /dev/null 2>&1
            kubectl delete secret artifact-registry > /dev/null 2>&1
            echo "$ kubectl create secret docker-registry artifact-registry --docker-server=https://${GCP_REGION}-docker.pkg.dev --docker-email=$EMAIL --docker-username=_json_key --docker-password=\"\$(cat $ENVDIR/image-pull.json)\" # to create docker registry secret" | pv -qL 100
            kubectl create secret docker-registry artifact-registry --docker-server=https://${GCP_REGION}-docker.pkg.dev --docker-email=$EMAIL --docker-username=_json_key --docker-password="$(cat $ENVDIR/image-pull.json)"
            echo
            echo "$ kubectl patch serviceaccount default -p '{\"imagePullSecrets\": [{\"name\": \"artifact-registry\"}]}' # to patch the default k8s service account with docker-registry image pull secret" | pv -qL 100
            kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "artifact-registry"}]}'
        fi
    ;;
    AZURE)
        if [ $MODE -eq 1 ]; then
            export STEP="${STEP},7i"
            echo
            echo "$ \$PROJDIR/kubectx eks # to set context" | pv -qL 100
            echo
            echo "$ kubectl create secret docker-registry artifact-registry --docker-server=https://\${GCP_REGION}-docker.pkg.dev --docker-email=\$EMAIL --docker-username=_json_key --docker-password=\"\$(cat $ENVDIR/image-pull.json)\" # to create docker registry secret" | pv -qL 100
            echo
            echo "$ kubectl patch serviceaccount default -p '{\"imagePullSecrets\": [{\"name\": \"artifact-registry\"}]}' # to patch the default k8s service account with docker-registry image pull secret" | pv -qL 100
         elif [ $MODE -eq 2 ]; then
            export STEP="${STEP},7"
            echo
            echo "$ $PROJDIR/kubectx aks # to set context" | pv -qL 100
            $PROJDIR/kubectx aks
            echo
            export EMAIL=$(gcloud config get-value core/account) > /dev/null 2>&1
            kubectl delete secret artifact-registry > /dev/null 2>&1
            echo "$ kubectl create secret docker-registry artifact-registry --docker-server=https://${GCP_REGION}-docker.pkg.dev --docker-email=$EMAIL --docker-username=_json_key --docker-password=\"\$(cat $ENVDIR/image-pull.json)\" # to create docker registry secret" | pv -qL 100
            kubectl create secret docker-registry artifact-registry --docker-server=https://${GCP_REGION}-docker.pkg.dev --docker-email=$EMAIL --docker-username=_json_key --docker-password="$(cat $ENVDIR/image-pull.json)"
            echo
            echo "$ kubectl patch serviceaccount default -p '{\"imagePullSecrets\": [{\"name\": \"artifact-registry\"}]}' # to patch the default k8s service account with docker-registry image pull secret" | pv -qL 100
            kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "artifact-registry"}]}'
        fi
    ;;
esac
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"8")
start=`date +%s`
source $ENVDIR/.env
case ${PLATFORM^^} in
    AWS)
        if [ $MODE -eq 1 ]; then
            echo
            echo "$ \$PROJDIR/aws/aws eks update-kubeconfig --name \$AWS_CLUSTER --region \$AWS_REGION # to update kubeconfig" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx eks=. # to switch context" | pv -qL 100
        else
            echo
            echo "$ \$PROJDIR/aws/aws eks update-kubeconfig --name $AWS_CLUSTER --region $AWS_REGION # to update kubeconfig" | pv -qL 100
            $PROJDIR/aws/aws eks update-kubeconfig --name $AWS_CLUSTER --region $AWS_REGION
            echo
            echo "$ $PROJDIR/kubectx eks=. # to switch context" | pv -qL 100
            $PROJDIR/kubectx eks=.
        fi
    ;;
    AZURE)
        if [ $MODE -eq 1 ]; then
            echo
            echo "$ /usr/bin/az aks get-credentials -n \$AZURE_CLUSTER -g \$AZ_RESOURCEGROUP # to retrieve cluster credentials" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx aks=. # to switch context" | pv -qL 100
        else
            echo
            echo "$ /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP # to retrieve cluster credentials" | pv -qL 100
            /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP
            echo
            echo "$ $PROJDIR/kubectx aks # to switch context" | pv -qL 100
            $PROJDIR/kubectx aks=.
        fi
    ;;
    GCP)
        if [ $MODE -eq 1 ]; then
            echo
            echo "$ gcloud container clusters get-credentials \$GCP_CLUSTER --zone \$GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx gke=. # to set context"
        else
            echo
            echo "$ gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
            gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE
            echo
            echo "$ $PROJDIR/kubectx gke=. # to set context"
            $PROJDIR/kubectx gke=.
        fi
    ;;
esac
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},8i"
    echo
    echo "$ curl -L \"https://storage.googleapis.com/gke-release/asm/istio-\${SERVICEMESH_VERSION}-linux-amd64.tar.gz\" | tar xz -C \$ENVDIR # to download the Anthos Service Mesh" | pv -qL 100
    echo
    echo "$ kubectl create namespace istio-system # to create a namespace called istio-system" | pv -qL 100
    echo
    echo "$ make -f \$ENVDIR/istio-\${SERVICEMESH_VERSION}/tools/certs/Makefile.selfsigned.mk root-ca # to generate a root certificate and key" | pv -qL 100
    echo
    echo "$ make -f \$ENVDIR/istio-\${SERVICEMESH_VERSION}/tools/certs/Makefile.selfsigned.mk \$ENVDIR/istio-\${SERVICEMESH_VERSION}/cluster1-cacerts # to generate an intermediate certificate and key" | pv -qL 100
    echo
    echo "$ kubectl create secret generic cacerts -n istio-system --from-file=\$ENVDIR/istio-\${SERVICEMESH_VERSION}/cluster1/ca-cert.pem --from-file=\$ENVDIR/istio-\${SERVICEMESH_VERSION}/cluster1/ca-key.pem --from-file=\$ENVDIR/istio-\${SERVICEMESH_VERSION}/cluster1/root-cert.pem --from-file=\$ENVDIR/istio-\${SERVICEMESH_VERSION}/cluster1/cert-chain.pem # to create a secret cacerts" | pv -qL 100
    echo
    echo "$ \$ENVDIR/istio-\${SERVICEMESH_VERSION}/bin/istioctl install --set profile=asm-multicloud -y # to install Anthos Service Mesh" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},8"
    echo
    echo "$ curl -L \"https://storage.googleapis.com/gke-release/asm/istio-${SERVICEMESH_VERSION}-linux-amd64.tar.gz\" | tar xz -C $ENVDIR # to download the Anthos Service Mesh" | pv -qL 100
    curl -L "https://storage.googleapis.com/gke-release/asm/istio-${SERVICEMESH_VERSION}-linux-amd64.tar.gz" | tar xz -C $ENVDIR
    echo
    echo "$ kubectl create namespace istio-system # to create a namespace called istio-system" | pv -qL 100
    kubectl create namespace istio-system
    echo
    echo "$ make -f $ENVDIR/istio-${SERVICEMESH_VERSION}/tools/certs/Makefile.selfsigned.mk root-ca # to generate a root certificate and key" | pv -qL 100
    make -f $ENVDIR/istio-${SERVICEMESH_VERSION}/tools/certs/Makefile.selfsigned.mk root-ca
    echo
    echo "$ make -f $ENVDIR/istio-${SERVICEMESH_VERSION}/tools/certs/Makefile.selfsigned.mk $ENVDIR/istio-${SERVICEMESH_VERSION}/cluster1-cacerts # to generate an intermediate certificate and key" | pv -qL 100
    make -f $ENVDIR/istio-${SERVICEMESH_VERSION}/tools/certs/Makefile.selfsigned.mk $ENVDIR/istio-${SERVICEMESH_VERSION}/cluster1-cacerts
    echo
    echo "$ kubectl create secret generic cacerts -n istio-system --from-file=$ENVDIR/istio-${SERVICEMESH_VERSION}/cluster1/ca-cert.pem --from-file=$ENVDIR/istio-${SERVICEMESH_VERSION}/cluster1/ca-key.pem --from-file=$ENVDIR/istio-${SERVICEMESH_VERSION}/cluster1/root-cert.pem --from-file=$ENVDIR/istio-${SERVICEMESH_VERSION}/cluster1/cert-chain.pem # to create a secret cacerts" | pv -qL 100
    kubectl create secret generic cacerts -n istio-system --from-file=$ENVDIR/istio-${SERVICEMESH_VERSION}/cluster1/ca-cert.pem --from-file=$ENVDIR/istio-${SERVICEMESH_VERSION}/cluster1/ca-key.pem --from-file=$ENVDIR/istio-${SERVICEMESH_VERSION}/cluster1/root-cert.pem --from-file=$ENVDIR/istio-${SERVICEMESH_VERSION}/cluster1/cert-chain.pem
    echo
    echo "$ $ENVDIR/istio-${SERVICEMESH_VERSION}/bin/istioctl install --set profile=asm-multicloud -y # to install Anthos Service Mesh" | pv -qL 100
    $ENVDIR/istio-${SERVICEMESH_VERSION}/bin/istioctl install --set profile=asm-multicloud -y
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},8x"
    echo
    echo "$ kubectl delete controlplanerevision -n istio-system # to delete revision" | pv -qL 100
    kubectl delete controlplanerevision -n istio-system 2> /dev/null
    echo
    echo "$ kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l operator.istio.io/component=Pilot # to delete configuration" | pv -qL 100
    kubectl delete validatingwebhookconfiguration,mutatingwebhookconfiguration -l operator.istio.io/component=Pilot 2> /dev/null
    echo
    echo "$ kubectl delete namespace istio-system asm-system --ignore-not-found=true # to delete namespace" | pv -qL 100
    kubectl delete namespace istio-system asm-system --ignore-not-found=true
    echo
    echo "$ kubectl delete namespace istio-system # to delete a namespace called istio-system" | pv -qL 100
    kubectl delete namespace istio-system --ignore-not-found=true 
    echo
    echo "$ kubectl delete secret cacerts -n istio-system # to delete secret cacerts" | pv -qL 100
    kubectl delete secret cacerts -n istio-system
    echo
    echo "$ $ENVDIR/istio-${SERVICEMESH_VERSION}/bin/istioctl uninstall --purge -y # to uninstall istio" | pv -qL 100
    $ENVDIR/istio-${SERVICEMESH_VERSION}/bin/istioctl uninstall --purge -y
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"9")
start=`date +%s`
source $ENVDIR/.env
case ${PLATFORM^^} in
    AWS)
        if [ $MODE -eq 1 ]; then
            echo
            echo "$ \$PROJDIR/aws/aws eks update-kubeconfig --name \$AWS_CLUSTER --region \$AWS_REGION # to update kubeconfig" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx eks=. # to switch context" | pv -qL 100
        else
            echo
            echo "$ \$PROJDIR/aws/aws eks update-kubeconfig --name $AWS_CLUSTER --region $AWS_REGION # to update kubeconfig" | pv -qL 100
            $PROJDIR/aws/aws eks update-kubeconfig --name $AWS_CLUSTER --region $AWS_REGION
            echo
            echo "$ $PROJDIR/kubectx eks=. # to switch context" | pv -qL 100
            $PROJDIR/kubectx eks=.
        fi
    ;;
    AZURE)
        if [ $MODE -eq 1 ]; then
            echo
            echo "$ /usr/bin/az aks get-credentials -n \$AZURE_CLUSTER -g \$AZ_RESOURCEGROUP # to retrieve cluster credentials" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx aks=. # to switch context" | pv -qL 100
        else
            echo
            echo "$ /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP # to retrieve cluster credentials" | pv -qL 100
            /usr/bin/az aks get-credentials -n $AZURE_CLUSTER -g $AZ_RESOURCEGROUP
            echo
            echo "$ $PROJDIR/kubectx aks # to switch context" | pv -qL 100
            $PROJDIR/kubectx aks=.
        fi
    ;;
    GCP)
        if [ $MODE -eq 1 ]; then
            echo
            echo "$ gcloud container clusters get-credentials \$GCP_CLUSTER --zone \$GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
            echo
            echo "$ \$PROJDIR/kubectx gke=. # to set context"
        else
            echo
            echo "$ gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
            gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE
            echo
            echo "$ $PROJDIR/kubectx gke=. # to set context"
            $PROJDIR/kubectx gke=.
        fi
    ;;
esac
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},9i"
    echo
    echo "$ kubectl create namespace hipster # to create namespace" | pv -qL 100
    echo
    echo "$ kubectl label namespace hipster istio-injection=enabled # to label namespaces for automatic sidecar injection" | pv -qL 100
    echo
    echo "$ kubectl -n hipster apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/kubernetes-manifests.yaml # to deploy application" | pv -qL 100
    echo
    echo "$ kubectl -n hipster apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/istio-manifests.yaml # to configure gateway" | pv -qL 100
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n hipster # to wait for the deployment to finish" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},9"
    echo
    echo "$ kubectl create namespace hipster # to create namespace" | pv -qL 100
    kubectl create namespace hipster
    echo
    echo "$ kubectl label namespace hipster istio-injection=enabled # to label namespaces for automatic sidecar injection" | pv -qL 100
    kubectl label namespace hipster istio-injection=enabled
    echo
    echo "$ kubectl -n hipster apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/kubernetes-manifests.yaml # to deploy application" | pv -qL 100
    kubectl -n hipster apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/kubernetes-manifests.yaml
    echo
    echo "$ kubectl -n hipster apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/istio-manifests.yaml # to configure gateway" | pv -qL 100
    kubectl -n hipster apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/master/release/istio-manifests.yaml
    echo
    echo "$ kubectl wait --for=condition=available --timeout=600s deployment --all -n hipster # to wait for the deployment to finish" | pv -qL 100
    kubectl wait --for=condition=available --timeout=600s deployment --all -n hipster
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},9x"
    echo
    echo "$ kubectl delete namespace hipster # to delete namespace" | pv -qL 100
    kubectl delete namespace hipster 2> /dev/null
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"10")
start=`date +%s`
source $ENVDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},10i"   
    echo
    echo "$ git config --global credential.https://source.developers.google.com.helper gcloud. # to configure git" | pv -qL 100
    echo
    echo "$ git config --global user.email \"\$(gcloud config get-value account)\" # to configure git" | pv -qL 100
    echo
    echo "$ git config --global user.name \"USER\" # to configure git" | pv -qL 100
    echo
    echo "$ git config --global init.defaultBranch main # to set branch" | pv -qL 100
    echo
    echo "$ gcloud source repos create \${APPLICATION_NAME}-k8s-repo --project \$GCP_PROJECT # to create repo" | pv -qL 100
    echo
    echo "$ gcloud source repos clone \${APPLICATION_NAME}-k8s-repo --project \$GCP_PROJECT # to clone repo" | pv -qL 100
    echo
    echo "$ gcloud beta builds triggers create cloud-source-repositories --project \$GCP_PROJECT --name=\"\${APPLICATION_NAME}-k8s-repo-trigger\" --repo=\${APPLICATION_NAME}-k8s-repo --branch-pattern=main --build-config=cloudbuild.yaml # to configure trigger" | pv -qL 100
    echo
    echo "$ cd \${APPLICATION_NAME}-k8s-repo # to change to repo directory" | pv -qL 100
    echo
    echo "$ cat <<EOF > Dockerfile
FROM golang:1.19.2 as builder
WORKDIR /app
RUN go mod init hello-app
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o /hello-app
FROM gcr.io/distroless/base-debian11
WORKDIR /
COPY --from=builder /hello-app /hello-app
ENV PORT 8080
USER nonroot:nonroot
CMD [\"/hello-app\"]
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF > main.go
package main

import (
    \"fmt\"
    \"log\"
    \"net/http\"
    \"os\"
)

func main() {
    mux := http.NewServeMux()
    mux.HandleFunc(\"\/\", hello)

    port := os.Getenv(\"PORT\")
    if port == \"\" {
        port = \"8080\"
    }

    log.Printf(\"Server listening on port \%s\", port)
    log.Fatal(http.ListenAndServe(\":\"+port, mux))
}

func hello(w http.ResponseWriter, r *http.Request) {
    log.Printf(\"Serving request: \%s\", r.URL.Path)
    host, _ := os.Hostname()
    fmt.Fprintf(w, \"Hello, world!\\n\")
    fmt.Fprintf(w, \"Version: 1.0.0\\n\")
    fmt.Fprintf(w, \"Hostname: \%s\\n\", host)
}
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF > hello_app_deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloweb
  labels:
    app: hello
spec:
  selector:
    matchLabels:
      app: hello
      tier: web
  template:
    metadata:
      labels:
        app: hello
        tier: web
    spec:
      containers:
      - name: hello-app
        image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 200m
EOF" | pv -qL 100
    echo
    echo "$ cat <<EOF > hello_app_service.yaml
apiVersion: v1
kind: Service
metadata:
  name: helloweb
  labels:
    app: hello
    tier: web
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: hello
    tier: web
EOF" | pv -qL 100
    echo
    echo "$ git add . # to add directory" | pv -qL 100
    echo
    echo "$ git commit -m \"Added files\" # to commit change" | pv -qL 100
    echo
    echo "$ git push origin main # to push change to main" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},10"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
    cd $ENVDIR
    echo
    echo "$ git config --global credential.https://source.developers.google.com.helper gcloud. # to configure git" | pv -qL 100
    git config --global credential.https://source.developers.google.com.helper gcloud.
    echo
    echo "$ git config --global user.email \"\$(gcloud config get-value account)\" # to configure git" | pv -qL 100
    git config --global user.email "$(gcloud config get-value account)" > /dev/null 2>&1
    echo
    echo "$ git config --global user.name \"USER\" # to configure git" | pv -qL 100
    git config --global user.name "USER" > /dev/null 2>&1 
    echo
    echo "$ git config --global init.defaultBranch main # to set branch" | pv -qL 100
    git config --global init.defaultBranch main
    echo
    gcloud source repos delete ${APPLICATION_NAME}-k8s-repo --project $GCP_PROJECT --quiet > /dev/null 2>&1 
    echo "$ gcloud source repos create ${APPLICATION_NAME}-k8s-repo --project $GCP_PROJECT # to create repo" | pv -qL 100
    gcloud source repos create ${APPLICATION_NAME}-k8s-repo --project $GCP_PROJECT 2> /dev/null
    echo
    rm -rf ${APPLICATION_NAME}-k8s-repo
    echo "$ gcloud source repos clone ${APPLICATION_NAME}-k8s-repo --project $GCP_PROJECT # to clone repo" | pv -qL 100
    gcloud source repos clone ${APPLICATION_NAME}-k8s-repo --project $GCP_PROJECT
    echo
    gcloud beta builds triggers delete cloud-source-repositories --project $GCP_PROJECT --quiet > /dev/null 2>&1 
    echo "$ gcloud beta builds triggers create cloud-source-repositories --project $GCP_PROJECT --name=\"${APPLICATION_NAME}-k8s-repo-trigger\" --repo=${APPLICATION_NAME}-k8s-repo --branch-pattern=main --build-config=cloudbuild.yaml # to configure trigger" | pv -qL 100
    gcloud beta builds triggers create cloud-source-repositories --project $GCP_PROJECT --name="${APPLICATION_NAME}-k8s-repo-trigger" --repo=${APPLICATION_NAME}-k8s-repo --branch-pattern=main --build-config=cloudbuild.yaml 2> /dev/null
    echo
    echo "$ cd ${APPLICATION_NAME}-k8s-repo # to change to repo directory" | pv -qL 100
    cd ${APPLICATION_NAME}-k8s-repo
    echo
    echo "$ cat <<EOF > Dockerfile
FROM golang:1.19.2 as builder
WORKDIR /app
RUN go mod init hello-app
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o /hello-app
FROM gcr.io/distroless/base-debian11
WORKDIR /
COPY --from=builder /hello-app /hello-app
ENV PORT 8080
USER nonroot:nonroot
CMD [\"/hello-app\"]
EOF" | pv -qL 100
cat <<EOF > Dockerfile
FROM golang:1.19.2 as builder
WORKDIR /app
RUN go mod init hello-app
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o /hello-app
FROM gcr.io/distroless/base-debian11
WORKDIR /
COPY --from=builder /hello-app /hello-app
ENV PORT 8080
USER nonroot:nonroot
CMD ["/hello-app"]
EOF
    echo
    echo "$ cat <<EOF > main.go
package main

import (
    \"fmt\"
    \"log\"
    \"net/http\"
    \"os\"
)

func main() {
    mux := http.NewServeMux()
    mux.HandleFunc(\"\/\", hello)

    port := os.Getenv(\"PORT\")
    if port == \"\" {
        port = \"8080\"
    }

    log.Printf(\"Server listening on port \%s\", port)
    log.Fatal(http.ListenAndServe(\":\"+port, mux))
}

func hello(w http.ResponseWriter, r *http.Request) {
    log.Printf(\"Serving request: \%s\", r.URL.Path)
    host, _ := os.Hostname()
    fmt.Fprintf(w, \"Hello, world!\\n\")
    fmt.Fprintf(w, \"Version: 1.0.0\\n\")
    fmt.Fprintf(w, \"Hostname: \%s\\n\", host)
}
EOF" | pv -qL 100
cat <<EOF > main.go
package main

import (
    "fmt"
    "log"
    "net/http"
    "os"
)

func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("/", hello)

    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }

    log.Printf("Server listening on port %s", port)
    log.Fatal(http.ListenAndServe(":"+port, mux))
}

func hello(w http.ResponseWriter, r *http.Request) {
    log.Printf("Serving request: %s", r.URL.Path)
    host, _ := os.Hostname()
    fmt.Fprintf(w, "Hello, world!\n")
    fmt.Fprintf(w, "Version: 1.0.0\n")
    fmt.Fprintf(w, "Hostname: %s\n", host)
}
EOF
    echo
    echo "$ cat <<EOF > hello_app_deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloweb
  labels:
    app: hello
spec:
  selector:
    matchLabels:
      app: hello
      tier: web
  template:
    metadata:
      labels:
        app: hello
        tier: web
    spec:
      containers:
      - name: hello-app
        image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 200m
EOF" | pv -qL 100
cat <<EOF > hello_app_deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloweb
  labels:
    app: hello
spec:
  selector:
    matchLabels:
      app: hello
      tier: web
  template:
    metadata:
      labels:
        app: hello
        tier: web
    spec:
      containers:
      - name: hello-app
        image: us-docker.pkg.dev/google-samples/containers/gke/hello-app:1.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 200m
EOF
    echo
    echo "$ cat <<EOF > hello_app_service.yaml
apiVersion: v1
kind: Service
metadata:
  name: helloweb
  labels:
    app: hello
    tier: web
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: hello
    tier: web
EOF" | pv -qL 100
cat <<EOF > hello_app_service.yaml
apiVersion: v1
kind: Service
metadata:
  name: helloweb
  labels:
    app: hello
    tier: web
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: hello
    tier: web
EOF
    echo
    echo "$ git add . # to add directory" | pv -qL 100
    git add .
    echo
    echo "$ git commit -m \"Added files\" # to commit change" | pv -qL 100
    git commit -m "Added files"
    echo
    echo "$ git push origin main # to push change to main" | pv -qL 100
    git push origin main
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},10x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
    echo
    echo "$ gcloud beta builds triggers delete ${APPLICATION_NAME}-k8s-repo-trigger --project $GCP_PROJECT # to delete trigger" | pv -qL 100
    gcloud beta builds triggers delete ${APPLICATION_NAME}-k8s-repo-trigger --project $GCP_PROJECT 
    echo
    echo "*** DO NOT DELETE REPO IF YOU INTEND TO RE-RUN THIS LAB. DELETED REPOS CANNOT BE REUSED WITHIN 7 DAYS ***"
    echo
    echo "*** To delete repo, run command \"gcloud source repos delete ${APPLICATION_NAME}-k8s-repo --project $GCP_PROJECT\" ***" | pv -qL 100
else
    export STEP="${STEP},10i"   
    echo
    echo " 1. Configure git" | pv -qL 100
    echo " 2. Set branch" | pv -qL 100
    echo " 3. Create repo" | pv -qL 100
    echo " 4. Configure trigger" | pv -qL 100
    echo " 5. Commit change" | pv -qL 100
    echo " 6. Push change to main" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"11")
start=`date +%s`
source $ENVDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},11i"   
    echo
    echo "$ git config --global credential.https://source.developers.google.com.helper gcloud. # to configure git" | pv -qL 100
    echo
    echo "$ git config --global user.email \"\$(gcloud config get-value account)\" # to configure git" | pv -qL 100
    echo
    echo "$ git config --global user.name \"USER\" # to configure git" | pv -qL 100
    echo
    echo "$ git config --global init.defaultBranch main # to set branch" | pv -qL 100
    echo
    echo "$ cd \${APPLICATION_NAME}-k8s-repo # to change to repo directory" | pv -qL 100
    echo
    echo "$ cat <<EOF > cloudbuild.yaml
steps:
- name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
  entrypoint: bash
  id: Deploy to AWS attached cluster
  args:
  - '-c'
  - |
    set -x && \
    export KUBECONFIG=\"\$HOME/.kube/config\" && \\
    gcloud container fleet memberships get-credentials \$AWS_CLUSTER && \\
    kubectl --kubeconfig \$HOME/.kube/config apply -f hello_app_deployment.yaml -f hello_app_service.yaml 
- name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
  entrypoint: bash
  id: Deploy to Azure attached cluster
  args:
  - '-c'
  - |
    set -x && \
    export KUBECONFIG=\"\$HOME/.kube/config\" && \\
    gcloud container fleet memberships get-credentials \$AZURE_CLUSTER && \\
    kubectl --kubeconfig \$HOME/.kube/config apply -f hello_app_deployment.yaml -f hello_app_service.yaml 
- name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
  entrypoint: bash
  id: Deploy to Anthos GKE cluster on GCP
  args:
  - '-c'
  - |
    set -x && \\
    export KUBECONFIG=\"\$HOME/.kube/config\" && \\
    gcloud container fleet memberships get-credentials \$GCP_CLUSTER && \\
    kubectl --kubeconfig \$HOME/.kube/config apply -f hello_app_deployment.yaml -f hello_app_service.yaml 
EOF" | pv -qL 100
    echo
    echo "$ git add . # to add directory" | pv -qL 100
    echo
    echo "$ git commit -m \"Added files\" # to commit change" | pv -qL 100
    echo
    echo "$ git push origin main # to push change to main" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},11"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
    echo
    cd $ENVDIR
    echo "$ git config --global credential.https://source.developers.google.com.helper gcloud. # to configure git" | pv -qL 100
    git config --global credential.https://source.developers.google.com.helper gcloud.
    echo
    echo "$ git config --global user.email \"\$(gcloud config get-value account)\" # to configure git" | pv -qL 100
    git config --global user.email "$(gcloud config get-value account)" > /dev/null 2>&1
    echo
    echo "$ git config --global user.name \"USER\" # to configure git" | pv -qL 100
    git config --global user.name "USER" > /dev/null 2>&1 
    echo
    echo "$ git config --global init.defaultBranch main # to set branch" | pv -qL 100
    git config --global init.defaultBranch main
    echo
    echo "$ cd ${APPLICATION_NAME}-k8s-repo # to change to repo directory" | pv -qL 100
    cd ${APPLICATION_NAME}-k8s-repo
    echo
    echo "$ cat <<EOF > cloudbuild.yaml
steps:
- name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
  entrypoint: bash
  id: Deploy to AWS attached cluster
  args:
  - '-c'
  - |
    set -x && \
    export KUBECONFIG=\"\$HOME/.kube/config\" && \\
    gcloud container fleet memberships get-credentials $AWS_CLUSTER && \\
    kubectl --kubeconfig $HOME/.kube/config apply -f hello_app_deployment.yaml -f hello_app_service.yaml 
- name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
  entrypoint: bash
  id: Deploy to Azure attached cluster
  args:
  - '-c'
  - |
    set -x && \
    export KUBECONFIG=\"\$HOME/.kube/config\" && \\
    gcloud container fleet memberships get-credentials $AZURE_CLUSTER && \\
    kubectl --kubeconfig $HOME/.kube/config apply -f hello_app_deployment.yaml -f hello_app_service.yaml 
- name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
  entrypoint: bash
  id: Deploy to Anthos GKE cluster on GCP
  args:
  - '-c'
  - |
    set -x && \\
    export KUBECONFIG=\"\$HOME/.kube/config\" && \\
    gcloud container fleet memberships get-credentials $GCP_CLUSTER && \\
    kubectl --kubeconfig $HOME/.kube/config apply -f hello_app_deployment.yaml -f hello_app_service.yaml 
EOF" | pv -qL 100
    cat <<EOF > cloudbuild.yaml
steps:
- name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
  entrypoint: bash
  id: Deploy to AWS attached cluster
  args:
  - '-c'
  - |
    set -x && \
    export KUBECONFIG="$HOME/.kube/config" && \
    gcloud container fleet memberships get-credentials $AWS_CLUSTER && \
    kubectl --kubeconfig $HOME/.kube/config apply -f hello_app_deployment.yaml -f hello_app_service.yaml 
- name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
  entrypoint: bash
  id: Deploy to Azure attached cluster
  args:
  - '-c'
  - |
    set -x && \
    export KUBECONFIG="$HOME/.kube/config" && \
    gcloud container fleet memberships get-credentials $AZURE_CLUSTER && \
    kubectl --kubeconfig $HOME/.kube/config apply -f hello_app_deployment.yaml -f hello_app_service.yaml 
- name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
  entrypoint: bash
  id: Deploy to Anthos GKE cluster on GCP
  args:
  - '-c'
  - |
    set -x && \
    export KUBECONFIG="$HOME/.kube/config" && \
    gcloud container fleet memberships get-credentials $GCP_CLUSTER && \
    kubectl --kubeconfig $HOME/.kube/config apply -f hello_app_deployment.yaml -f hello_app_service.yaml 
EOF
    echo
    echo "$ git add . # to add directory" | pv -qL 100
    git add .
    echo
    echo "$ git commit -m \"Added files\" # to commit change" | pv -qL 100
    git commit -m "Added files"
    echo
    echo "$ git push origin main # to push change to main" | pv -qL 100
    git push origin main
    stty echo # to ensure input characters are echoed on terminal
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},11x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},11i"   
    echo
    echo " 1. Set service account" | pv -qL 100
    echo " 2. Grant role" | pv -qL 100
    echo " 3. Assign role" | pv -qL 100
    echo " 4. Configure clouddeploy" | pv -qL 100
    echo " 5. Commit change" | pv -qL 100
    echo " 6. Push change to main" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;
 
"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md  > /dev/null 2>&1
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
