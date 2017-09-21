#!/bin/bash
#
# Copyright 2016 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS-IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
# Description :  Used to build, deploy and teardown the TensorFlow for 
#                teams solution on Google Container Engine.
# This is not an official Google product.
#
VERSION='1.0'
SCRIPT_NAME="gke-jupyter-classroom.sh"
#exit on any error
set -e
# Prints the usage for this script
function print_usage() {
  echo "Init Script for Google Contianer Enginer Jupyter Classroom: ${VERSION}"
  cat <<'EOF'
Usage: ./gke-jupyter-classroom.sh [ options ] <command>
Description:
Used to build, deploy and teardown a Jupyter classroom on Google Container Engine


This script is designed to be run within the Google Cloud Shell, which will have the
following  utilities pre-installed:
    gcloud (Google Cloud SDK)
    kubectl (Kubernetes control)
    openssl (certificate generation)
    docker  (Docker container system)

If you build your own Docker images and push them to the Container Repository, you will
have to build and push all the primary images: 
    JupyterHub
    Jupyter+TensorFlow
    Nginx Proxy
    Jupyter+Datalab

You will have to manually setup an NFS Filer Server in GCE to initialize this solution.
Or use the Cloud Launcher to create one. 

Flags:
  -a, --admin-user
    Specify the first default admin user's email address, this is likely your email

  -A, --autoscale-nodes
    Enables Kubernetes Autoscaling by sending in an integer value here as the max number of 
    nodes, limit is 32 nodes, if number less than the -n --nodes it will not be enabled

  -c, --cluster-name
    Specify a name for the GKE cluster, default is tf4teams

  -C, create-cluster
    Just create the cluster in the --zone specified using the --cluster-name specified
   
  -d, deploy
    Deploy the solution to GKE

  -D, --domain
    Specify the domain name you will use with your certificates and OAUTH.  If you leave
    this blank, it will create a static IP and use xip.io for your domain

  -f, --filer-ip
    Speciy the IP address of the shared NFS file server to save the Jupyter Notebooks and
    JupyterHub config files.  This can also be a domain name

  -F, --filer-path
    *** Do not change this if you are using the Cloud Launcher shared file server, it will not
    accept any other value for the Stroage name field other than data. ***
    Specify the file path on the NFS file server that will be mounted as the root JupyterHub
    directory. default is /data

  -i, --image-prefix
    Specify the prefix of the Docker image before you build it and push it to cloud repository
  
  -m, --machine-type
    Specify the machine type to use in the cluster creation, default: n1-highcpu-8

  -M, --subdomain
    use a different subdomain prefix than the default jhub.  

  -n, --nodes
    Specify the number of nodes to create in your GKE cluster, defaults to 3

  -o, --oauth-client
    The OAUTH Client ID value for your domain

  -O, --oauth-secret
    The OAUTH Client Secret value for your domain 

  -p, --push-image
    push the new Docker image to the GKE Repository

  -r, --repo-path
    change the default repository path for deploy will be appended to 'gcr.io/'
	for build command it will defautl to ${GCP_PROJECT}/${IMAGE_PREFIX}
	for deploy command it will default to 'cloud-solutions-images'

  -s, --sk ip-certs
    skip the creation of self signed certificates, presumes that you manually placed the correct
    files in the /tmp directory of your cloud shell instance

  -S, --signed-cert
    you have to add the trusted.crt file to the /tmp directory, and this will add it to the Nginx secrets 
    record for SSL in the case that a trusted certificate is being used
  
  -u, --use-ssl-proxy
    use the SSL Proxy network feature instead of the Nginx Proxy Kubernetes Pod

  -v, --verbose
    print verbose logging

  -x, --dry-run
    execute the script in dry run mode which will create the temporary yaml templates and 
    show details about what would have happened
  
  -z, --zone
    enter the Cloud Platform zone, region will be extracted from this cmd: gcloud compute zones list
    

Commands:
  build, deploy, teardown, commands, options

build                 Build one of the Docker images and optionally push to Container Registry
                      The following build targets:
                      -    all  = build them all
                      -    deep = Jupyter + Tensorflow with DeepDream notebook
                      -    ngx = Nginx Proxy image
                      -    tools = Jupyter + Tensorflow, Google Datalab, & Dataflow SDK
                      -    jhub = JupyterHub image

create-cluster

deploy                Deploy the solution to Container Engine

teardown              Remove the solution from Cloud Platform

commands              List available commands

options               list available options

Examples:
  build and push all the containers to your repository with the my-images image prefix path

  ./gke-jupyter-classroom.sh --push-image --image-prefix my-images build all
  ./gke-jupyter-classroom.sh -pi my-images -b all

  create and deploy to a new cluster 

  ./gke-jupyter-classroom.sh --cluster-name jupyterhub1 --autoscale-nodes 6 --nodes 1 \
       --filer-path /jupyterhub --filer-ip 10.240.0.6 --image-prefix my-images \
       --admin-user youremail@gmail.com deploy
  
  teardown the environment
  ./gke-jupyter-classroom.sh --cluster-name jupyterhub1  teardown
  

EOF
}

# List all commands for command completion.
function commands() {
    print_usage | sed -n -e '/^Commands:/,/^$/p' | tail -n +2 | head -n -1 | tr -d ','
}

# List all options for command completion.
function options() {
    print_usage | grep -E '^ *-' | tr -d ','
}

# Override the date function
function prepare_date() {
    date "$@"
}

# Prefix a date prior to echo output
function loginfo() {
    if  ${LOG_OUTPUT}; then
     echo "$(prepare_date +%F_%H:%M:%S): ${@}" >> "${LOG_FILE}"
    else
     echo "$(prepare_date +%F_%H:%M:%S): ${@}"
    fi
}

# Only used if -v --verbose is passed in
function logverbose() {
    if ${VERBOSE}; then
    loginfo "VERBOSE: ${@}"
    fi
}

# Pass errors to stderr.
function logerror() {
    loginfo "ERROR: ${@}" >&2
    let ERROR_COUNT++
}

# Bad option was found.
function print_help() {
    logerror "Unknown Option Encountered. For help run '${SCRIPT_NAME} --help'"
    print_usage
    exit 1
}

function test() {
    loginfo "Testing stuff"
    verify_ip
     if [ ${ERROR_COUNT} -gt 0 ]; then
        loginfo "*************ERRORS WHILE TESTING*************"
        exit 1
    fi
}

# Validate that all configuration options are correct and no conflicting options are set
function validate() {
    if [ -z ${GCLOUD} ]; then
        logerror "Cannot find gcloud utility please make sure it is in the PATH"
        exit 1
    fi
    if [ ${ACTION} = "build" ]; then

        if [ -z ${DOCKER} ]; then
        logerror "Cannot find docker utility please make sure it is in the PATH"
        fi
        if ${PUSH_IMAGE} && [ -z ${GCLOUD} ]; then
            logerror "gcloud sdk not found to push image to Container Repository"
        fi
        verify_gcp_project
        if [ -z "${REPOSITORY_PATH}" ]; then
            REPOSITORY_PATH="${GCP_PROJECT}/${IMAGE_PREFIX}" 
        fi
    fi
    #used to verify specified zone is valid
    ZONES="$(${GCLOUD} compute zones list)" 

    if [ ${ACTION} = "deploy" ]; then
        logverbose "Verify gcloud project"
        verify_gcp_project
        if [ -z "${REPOSITORY_PATH}" ]; then
            REPOSITORY_PATH="cloud-solutions-images" 
        fi
        logverbose "Verify zone is correct"
        if ! grep -q "^${ZONE}" <<< "${ZONES}" ; then 
            logerror "Cloud Platform Zone ${ZONE} is invalid, use one of ${ZONES}"
        fi
        logverbose "Verify kubectl installed"
        if [ -z ${KUBECTL} ]; then
            logerror "kubectl is not installed and/or in the PATH"
        fi
       
        logverbose "Verify AdminUser not Null"
        if [ -z ${ADMIN_USER} ]; then
            logerror "please specify an admin-user in the format name@address.com"
        fi
        logverbose "Verify IP Filer"
        verify_ip
        if [ -z ${FILER_PATH} ]; then
            logerror "FILER_PATH value is empty"
        fi

        if [ -z ${DOMAIN} ]; then
            loginfo "DOMAIN value is empty, using xip.io for domain and creating static IP" 
            loginfo "Static IP costs you more money ;) so make sure to clean it up later"
        else
            if [ -z ${OAUTH_CLIENT_ID} ] || [ -z ${OAUTH_CLIENT_SECRET} ]; then
                logerror "OAUTH_CLIENT_ID or CLIENT_SECRET are empty"
            fi
        fi
    fi

    if [ ${ACTION} == "create-cluster" ]; then
        logverbose "Verify gcloud project"
        verify_gcp_project
        logverbose "Verify zone is correct"
        if ! grep -q "^${ZONE}" <<< "${ZONES}" ; then 
            logerror "Cloud Platform Zone ${ZONE} is invalid, use one of ${ZONES}"
        fi
    fi

    if [ ${ACTION}  == "teardown" ]; then
        loginfo "verify you want to destroy this environment?"
    fi

    logverbose "ERROR_COUNT: ${ERROR_COUNT}"

    if [ ${ERROR_COUNT} -gt 0 ]; then
        loginfo "*************ERRORS WHILE VALIDATING ARGUMENTS*************"
        exit 1
    fi
    loginfo "*************SUCCESSFULLY VALIDATED ARGUMENTS**************"
}

function verify_gcp_project() {
    if [ -z ${GCP_PROJECT} ]; then
        GCP_PROJECT="$(gcloud config list 2> /dev/null | grep project | awk -F" = " '{print $2}')"
        loginfo "GCP_PROJECT detected: ${GCP_PROJECT}"
    fi
    if [ -z ${GCP_PROJECT} ]; then
        logerror "Not GCP_PROJECT set ${GCP_PROJECT}"
    else
        PROJECT_ID=${GCP_PROJECT} #save in case it's modified
        loginfo "Verify GCP_PROJECT is valid:"
        if ! grep -q ": ACTIVE" <<< "$(gcloud projects describe ${GCP_PROJECT})"; then
            logerror "Project ${GCP_PROJECT} does not appear to be active"
        else
            loginfo "Setting ${GCP_PROJECT} as the default project"
            ${GCLOUD} config set project ${GCP_PROJECT} 2> /dev/null
            if grep -q ":" <<< ${GCP_PROJECT}; then
                GCP_PROJECT="$(echo ${GCP_PROJECT} | sed 's/:/\//')"
                loginfo "Removed ':' from GCP Project for GKE repository- ${GCP_PROJECT}"
            fi
        fi
    fi
}

function verify_ip() {

    if ! grep -q '[[:alpha:]]' <<< $FILER_IP ; then  #this is a domain name then
        read valid <<< $( awk -v ip="${FILER_IP}" '
        BEGIN { n=split(ip, i,"."); e = 0;
        if (6 < length(ip) && length(ip) < 16 && n == 4 && i[4] > 0 && i[1] > 0){
            for(z in i){if (i[z] !~ /[0-9][0-9]?[0-9]?/ || i[z] > 255){e=1;break;}}
        } else { e=2; } print(e);}')
        logverbose "Verifying IP: Output = $valid"
        if [ $valid != 0 ]; then
            logerror "Invalid IP address ${FILER_IP} detected for shared filer server"
        fi
    fi
}


function build() {
    loginfo "Starting build ${BUILD_TARGET}"
    case ${BUILD_TARGET} in
        "all")
            build_deepdream
            build_nginx_proxy
            build_jupyterhub
            build_gcptools
            ;;
        "deep")
            build_deepdream
            ;;
        "ngx") 
            build_nginx_proxy 
            ;;
        "jhub") 
            build_jupyterhub 
            ;;
        "tools") 
            build_gcptools 
            ;;
        ?)
            logerror "Unknown Build target: ${BUILD_TARGET}"
            exit 1
            ;;
  esac
}


function build_all() {
    build_deepdream
    build_gcptools
    build_jupyterhub
    build_nginx_proxy
}

#deep
function build_deepdream() {
    logverbose "building ${IMAGE_PREFIX}/tf-deepdream-su"
    docker build -t ${IMAGE_PREFIX}/tf-deepdream-su ./jupyter/tf-deepdream/
    logverbose "tagging ${IMAGE_PREFIX}/tf-deepdream-su"
    docker tag "${IMAGE_PREFIX}/tf-deepdream-su" "gcr.io/${REPOSITORY_PATH}/tf-deepdream-su"
    push_image_to_repo "gcr.io/${REPOSITORY_PATH}/tf-deepdream-su"
}

#tools
function build_gcptools() {
    docker build -t ${IMAGE_PREFIX}/tf-gcptools-su  ./jupyter/gcp-tools/
    docker tag "${IMAGE_PREFIX}/tf-gcptools-su"  "gcr.io/${REPOSITORY_PATH}/tf-gcptools-su"
    push_image_to_repo "gcr.io/${REPOSITORY_PATH}/tf-gcptools-su" 
}

#jhub
function build_jupyterhub() {
    logverbose "building ${IMAGE_PREFIX}/jupyterhub"
    docker build -t ${IMAGE_PREFIX}/jupyterhub ./jupyterhub/
    docker tag "${IMAGE_PREFIX}/jupyterhub" "gcr.io/${REPOSITORY_PATH}/jupyterhub"
    push_image_to_repo "gcr.io/${REPOSITORY_PATH}/jupyterhub"
}

#ngx
function build_nginx_proxy() {
    logverbose "Building ${IMAGE_PREFIX}/k8s-cmap-nginx"
    docker build -t ${IMAGE_PREFIX}/k8s-cmap-nginx ./proxy/
    logverbose "Tagging ${IMAGE_PREFIX}/k8s-cmap-nginx"
    docker tag "${IMAGE_PREFIX}/k8s-cmap-nginx" "gcr.io/${REPOSITORY_PATH}/k8s-cmap-nginx"
    push_image_to_repo "gcr.io/${REPOSITORY_PATH}/k8s-cmap-nginx"
}

function push_image_to_repo() {
    if ${PUSH_IMAGE} ; then
        loginfo "uploading image ${1} to repository"
        ${GCLOUD} docker push ${1}
    fi
}

function deploy() {
    create-cluster
    create_k8s_namespace
    if [ -z ${DOMAIN} ]; then
        create_static_ip
    fi
    create_jhub_k8s_manifest
    create_certificate_secret
    create_oauth_secrets
    create_jhub_configmap
    apply_jhub_to_cluster
    if ${USE_SSL_PROXY} ; then
        create_ssl_proxy
    else
        create_nginx_proxy
    fi
    print_final_instructions
}

function teardown() {
    loginfo "Initializing Teardown sequence..." \
    "#delete the cluster" \
    "#delete the health checks " \
    "#delete the firewall rules" \
    "#delete the IP address" \
    "#delete the storage VM"
    if ${DRY_RUN} ; then
        loginfo "Dry Run: creating Cluster ${CLUSTER_NAME} with ${CLUSTER_NODES} nodes of machine: ${MACHINE_TYPE}"
    else
        set +e
        ${GCLOUD} container clusters get-credentials ${CLUSTER_NAME} --zone ${ZONE}
        if ${GCLOUD}  compute ssl-certificates list | grep -q ${CLUSTER_NAME}-ssl-cert ; then
            ${GCLOUD}  compute ssl-certificates delete ${CLUSTER_NAME}-ssl-cert --quiet
        fi
        ${KUBECTL} delete secrets --namespace jupyterhub jupyterhub  
        ${KUBECTL} delete secrets --namespace jupyterhub jhub-tls  
        ${KUBECTL} delete configmaps --namespace jupyterhub jhub-manifests  
        ${KUBECTL} delete -f ./jupyterhub.yaml
        ${KUBECTL} delete -f ./sslproxy.yaml
        #${GCLOUD} compute firewall-rules delete ${CLUSTER_NAME}-proxy-fw --quiet
        ${KUBECTL} delete configmaps --namespace jupyterhub jhub-nginx-conf
        #${GCLOUD} compute http-health-checks delete ${PROXY_HEALTH} --quiet
        ${KUBECTL} delete --all pods --namespace jupyterhub
        loginfo "please manually delete your static IP : ${GCLOUD} compute addresses delete ${CLUSTER_NAME}-static-ip --region ${REGION}"
        if ${GCLOUD} container clusters list 2> /dev/null | grep -q ${CLUSTER_NAME} ; then
           loginfo "execute this command to delete your cluster: " \
                   "${GCLOUD} container clusters delete ${CLUSTER_NAME} -z ${ZONE}"
        fi
        set -e
        loginfo "Don't forget to delete your file server and if you manually made a static IP address "
    fi
}

function create-cluster() {
    if ${DRY_RUN} ; then
        loginfo "Dry Run: creating Cluster ${CLUSTER_NAME} with ${CLUSTER_NODES} nodes of machine: ${MACHINE_TYPE}"
    else
        if ! ${GCLOUD} container clusters list 2> /dev/null | grep -q ${CLUSTER_NAME} ; then
            ${GCLOUD} container clusters create ${CLUSTER_NAME} \
                --machine-type ${MACHINE_TYPE} \
                --num-nodes ${CLUSTER_NODES} \
                --zone   ${ZONE} ${AUTOSCALING} \
                --scopes "https://www.googleapis.com/auth/projecthosting,storage-rw,bigquery"
            ${GCLOUD} container clusters get-credentials ${CLUSTER_NAME} --zone ${ZONE}
        fi
    fi
}

function create_static_ip() {
    if ${DRY_RUN} ; then
        loginfo "Dry Run: creating static IP address ${CLUSTER_NAME}-static-ip"
        STATIC_IP="dryrun.ima.static.ip"
        DOMAIN="${STATIC_IP}.xip.io"
        SUBDOMAIN="${SUBDOMAIN_PFIX}.${DOMAIN}"
    else
        if ! ${GCLOUD} compute addresses list | grep -q ${CLUSTER_NAME}-static-ip ; then
            flags="--region ${REGION}"
            if ${USE_SSL_PROXY} ; then
                flags="--global"
            fi
            ${GCLOUD} compute addresses create ${CLUSTER_NAME}-static-ip ${flags}
            get_static_ip
            while [ -z ${STATIC_IP} ]; do
                loginfo "Sleeping for 10 seconds while static ip creation completes"
                logverbose "Detecting IP for new Ingress Service this may take up to a minute"
                get_static_ip
                sleep 10s
            done
 
        else
            logverbose "static IP address ${CLUSTER_NAME}-static-ip already created"
            get_static_ip
        fi
        DOMAIN="${STATIC_IP}.xip.io"
        SUBDOMAIN="${SUBDOMAIN_PFIX}.${DOMAIN}"
        loginfo "User Action Required: Please follow the instructions to create an Web Application Oauth configuration"
        loginfo "use the Cloud Console to access the API Manager credentials section"
        loginfo "https://console.cloud.google.com/apis/credentials?project=${PROJECT_ID}"
        loginfo "use these values origins field: https://${SUBDOMAIN}  callback url: https://${SUBDOMAIN}/hub/oauth_callback "
        if [  -z ${OAUTH_CLIENT_ID} ]; then
            read -p "enter the OAUTH_CLIENT_ID now: " OAUTH_CLIENT_ID
        fi
        if [  -z ${OAUTH_CLIENT_SECRET} ]; then
            read -p "enter the OAUTH_CLIENT_SECRET now: " OAUTH_CLIENT_SECRET
        fi
                
    fi

}

function get_static_ip() {
    STATIC_IP="$(${GCLOUD} compute addresses list 2> /dev/null | grep ${CLUSTER_NAME}-static-ip | awk '{print $3}')"
}

function create_nginx_proxy() {
    if ${DRY_RUN} ; then
        loginfo "Dry Run: Setting up Nginx proxy, please review the sslproxy.yaml manifest file"
        create_proxy_k8s_manifest
    else
        add_tag_to_gke_instances
        create_nginx_configmap
        #create_health_check_firewall_rule "tcp:443"
        create_proxy_k8s_manifest
        apply_proxy_to_cluster
        #create_http_proxy_health_check
        #associate_health_check_with_target_pool
    fi

}

## Add a special tag so Firewall rules apply only to these instances
function add_tag_to_gke_instances() {
    if ${DRY_RUN} ; then
        loginfo "Dry Run: adding ${SSL_TAG} tag"
    else
        ${GCLOUD} compute instances list | grep ${CLUSTER_NAME} | awk  '{print $1}' \
        | xargs -n1 -I{} bash -c "gcloud compute instances add-tags  {} --tags ${SSL_TAG} --zone ${ZONE}"
    fi
}

function create_jhub_k8s_manifest() {
    loginfo "Creating Jhub k8s manifest, please review the resulting file: jupyterhub.yaml"
    sed  "s|<FILER_IP>|${FILER_IP}|g" ./jupyterhub/jupyterhub.yaml.tmp | \
    sed  "s|<FILER_PATH>|${FILER_PATH}|g" | sed "s|<ADMIN_USER>|${ADMIN_USER}|g" | \
    sed "s|<REPOSITORY_IMAGE_PATH>|gcr.io/${REPOSITORY_PATH}|g" | \
    sed "s|<SINGLE_USER_IMAGE>|${SINGLE_USER_IMAGE}|" > ./jupyterhub.yaml
}

function create_proxy_k8s_manifest() {
    local static_yaml=''
    if [ ! -z ${STATIC_IP} ]; then
        static_yaml="loadBalancerIP: ${STATIC_IP}"
    fi
    sed "s|<REPOSITORY_IMAGE_PATH>|gcr.io/${REPOSITORY_PATH}|" ./proxy/sslproxy.yaml.tmp | \
    sed "s|<STATIC_IP>|${static_yaml}|" > ./sslproxy.yaml
}

function create_k8s_namespace() {
    if ${DRY_RUN} ; then
        loginfo "Dry Run: creating K8s namespace: jupyterhub"
    else
        if ! ${KUBECTL} get ns | grep -q jupyterhub ; then
            ${KUBECTL} create ns jupyterhub #2> /dev/null
        else
            loginfo "jupyterhub k8s namespace already exists"
        fi
    fi
}

function create_oauth_secrets() {
    if ${DRY_RUN} ; then
        loginfo "Dry Run: Setting up oauth secrets "
    else
        ${KUBECTL}  create secret generic jupyterhub \
            --from-literal=oauth-client-id=${OAUTH_CLIENT_ID} \
            --from-literal=oauth-client-secret=${OAUTH_CLIENT_SECRET} \
            --from-literal=oauth-callback-url=https://${SUBDOMAIN}/hub/oauth_callback --namespace jupyterhub
    fi
}

function create_jhub_configmap() {
     if ${DRY_RUN} ; then
        loginfo "Dry Run: Setting up Jhub ConfigMap "
    else
        ${KUBECTL} create configmap jhub-manifests \
            --from-file=jupyterhub/custom_manifests/ \
            --namespace jupyterhub
    fi
}

function create_nginx_configmap() {
     if ${DRY_RUN} ; then
        loginfo "Dry Run: Setting up Nginx ConfigMap "
    else
        ${KUBECTL} create configmap  jhub-nginx-conf \
            --from-file=proxy/nginx.conf \
            --namespace jupyterhub
    fi
}

function apply_jhub_to_cluster() {
    if ${DRY_RUN} ; then
        loginfo "Dry Run: Applying jupyterhub.yaml with kubectl apply -f ./jupyterhub.yaml"
    else
        ${KUBECTL} apply -f ./jupyterhub.yaml
    fi
}

function apply_proxy_to_cluster() {
    if ${DRY_RUN} ; then
        loginfo "Dry Run: Applying sslproxy.yaml with: kubectl apply -f ./sslproxy.yaml"
    else
        ${KUBECTL} apply -f ./sslproxy.yaml
    fi
}

function create_health_check_firewall_rule() {
    ${GCLOUD} compute firewall-rules create ${CLUSTER_NAME}-proxy-fw \
    --source-ranges 130.211.0.0/22 \
    --target-tags ${SSL_TAG} \
    --allow ${1}
}

function create_http_proxy_health_check() {
    ${GCLOUD} compute http-health-checks create ${PROXY_HEALTH} --port 80 --request-path /healthcheck
}


function associate_health_check_with_target_pool() {

    local fwd_rule
    SERVICE_IP="$(${KUBECTL} describe services --namespace jupyterhub | grep Ingress | awk  '{print $3}')"
    if [ ! -z ${STATIC_IP} ]; then
        SERVICE_IP=${STATIC_IP}
    fi
    loginfo "Sleeping for 10 seconds to allow network configurations to fully complete"
    sleep 10s
    while [ -z ${SERVICE_IP} ]; do
        
        loginfo "Detecting IP for new Ingress Service this may take several minutes"
        SERVICE_IP="$(${KUBECTL} describe services --namespace jupyterhub | grep -i "Ingress" | awk  '{print $3}')"
        sleep 5s
    done
    logverbose "detected forwarding rules from IP"
    fwd_rule="$(${GCLOUD} compute forwarding-rules list --filter="region:(${REGION})" |  grep "${SERVICE_IP}" | awk '{print $1}')"
    while [ -z ${fwd_rule} ]; do
        loginfo "Detecting Forwarding Rule this may take several minutes"
        fwd_rule="$(${GCLOUD} compute forwarding-rules list --filter="region:(${REGION})" |  grep "${SERVICE_IP}" | awk '{print $1}')"
        sleep 5s
    done
    logverbose "service_ip=${SERVICE_IP}  fwd_rule=${fwd_rule}"
    logverbose "${GCLOUD} compute target-pools add-health-checks ${fwd_rule} --http-health-check ${PROXY_HEALTH} --region ${REGION} "
    ${GCLOUD} compute target-pools add-health-checks ${fwd_rule} --http-health-check ${PROXY_HEALTH} --region ${REGION} 
}


function create_certificate_secret() {
    loginfo "If you want to use signed certificates, please look at the " \
            "create_unsigned_certificates function of this script and manually use your certs"
    if ${DRY_RUN} ; then
        loginfo "Dry Run: Setting creating SSL certificates and k8's secret "
    else
        if ${SKIP_CERTS} ; then
            loginfo "Skipping certificates, you should have certs already made /tmp/tls.crt /tmp/tls.key /tmp/dhparam.pem"
        else
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout /tmp/tls.key -out /tmp/tls.crt -subj "/CN=${SUBDOMAIN}/O=${DOMAIN}"
            openssl dhparam -out /tmp/dhparam.pem 2048
        fi
        ${GCLOUD} compute ssl-certificates create  ${SSL_TAG}-cert \
            --certificate /tmp/tls.crt \
            --private-key /tmp/tls.key
        ${KUBECTL} create secret generic jhub-tls \
            --from-file=/tmp/tls.crt \
            --from-file=/tmp/tls.key ${TRUSTED_CRT} \
            --from-file=/tmp/dhparam.pem --namespace jupyterhub
    fi
}

function print_final_instructions() {

    loginfo "-----------COMPLETED------------"
    if ! ${DRY_RUN} ; then
        if [ -z ${STATIC_IP} ]; then
            loginfo "Ephemeral IP created: ${SERVICE_IP} please associate a new A record with this domain: ${SUBDOMAIN}"
        else
            loginfo "Static IP created: ${STATIC_IP} using xip.io : https://${SUBDOMAIN}"
        fi
    fi
}

## This section uses the new beta feature of SSL Proxy in GCP Networking
## instead of the Nginx SSL Proxy container
function create_ssl_proxy() {
    loginfo "initialize SSL Proxy configuration"

    #add firewall rule for port 30000, which was exposed in the hubservice manifest
    create_health_check_firewall_rule "tcp:30000"

    #create a new unmanaged instance group with the GKE Nodes created earlier
    ${GCLOUD} compute instance-groups unmanaged create us-${CLUSTER_NAME}-ig1 --zone ${ZONE}
    local instances="$(${GCLOUD} compute instances list | grep ${CLUSTER_NAME} | awk -vORS=, '{print $1}'|  sed 's/,$/\n/')"

    ${GCLOUD} compute instance-groups unmanaged add-instances us-${CLUSTER_NAME}-ig1 \
      --instances ${instances} \
      --zone ${ZONE}


    #Create a named port for the backend-service
    ${GCLOUD} compute instance-groups unmanaged set-named-ports us-${CLUSTER_NAME}-ig1 \
      --named-ports jhub:30000 \
      --zone ${ZONE}

    #Create the health-check 
    ${GCLOUD} beta compute health-checks create tcp ${CLUSTER_NAME}-health --port 30000

    #Create the Backend-Service
    ${GCLOUD} beta compute backend-services create ${CLUSTER_NAME}-backend-service \
      --protocol TCP \
      --health-check ${CLUSTER_NAME}-health \
      --timeout 60m \
      --port-name jhub  \
      --port 30000

    #Add the instance group to the backend-service
    ${GCLOUD} beta compute backend-services add-backend ${CLUSTER_NAME}-backend-service \
      --instance-group us-${CLUSTER_NAME}-ig1 \
      --zone ${ZONE}

    #Create the SSL Proxy with the certificate pointed at the backend-service
    ${GCLOUD} beta compute target-ssl-proxies create ${CLUSTER_NAME}-target-ssl-proxy  \
      --backend-service ${CLUSTER_NAME}-backend-service \
      --ssl-certificate ${SSL_TAG}-cert 

    #Create the forwarding rule to send traffic to the SSL Proxy on the new static IP
    ${GCLOUD} beta compute forwarding-rules create ${CLUSTER_NAME}-global-forule \
      --global \
      --target-ssl-proxy ${CLUSTER_NAME}-target-ssl-proxy \
      --address ${STATIC_IP} \
      --port-range 443
}




# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "build")             set -- "$@" "-b" ;;
    "deploy")            set -- "$@" "-d" ;;
    "commands")          commands && exit 0 ;;
    "create-cluster")    set -- "$@" "-C" ;;
    "options")           options && exit 0 ;;
    "test")              set -- "$@" "-t" ;;
    "teardown")          set -- "$@" "-T" ;;
    "--autoscale-nodes") set -- "$@" "-A" ;;
    "--admin-user")      set -- "$@" "-a" ;;
    "--cluster-name")    set -- "$@" "-c" ;;
    "--domain")          set -- "$@" "-D" ;;
    "--dry-run")         set -- "$@" "-x" ;;
    "--filer-ip")        set -- "$@" "-f" ;;
    "--filer-path")      set -- "$@" "-F" ;;
    "--help")            set -- "$@" "-h" ;;
    "--image-prefix")    set -- "$@" "-i" ;;
    "--machine-type")    set -- "$@" "-m" ;;
    "--nodes")           set -- "$@" "-n" ;;
    "--oauth-client")    set -- "$@" "-o" ;;
    "--oauth-secret")    set -- "$@" "-O" ;;
    "--push-image")      set -- "$@" "-p" ;;
    "--repo-path")       set -- "$@" "-r" ;;
    "--skip-certs")      set -- "$@" "-s" ;;
    "--signed-cert")     set -- "$@" "-S" ;;
    "--subdomain")       set -- "$@" "-M" ;;
    "--use-ssl-proxy")   set -- "$@" "-u" ;;
    "--zone")            set -- "$@" "-z" ;;
       *)                set -- "$@" "$arg"
  esac
done

while getopts 'a:A:b:c:CdD:f:F:hi:m:M:n:o:O:pr:sStTuvxz:' OPTION
do
  case $OPTION in
      A)
          AUTOSCALING_MAX=${OPTARG}
          ;;
      a)
          ADMIN_USER="${OPTARG}"
          ;;
      b)
          ACTION="build"
          BUILD_TARGET="${OPTARG}"
          ;;
      c)
          CLUSTER_NAME="${OPTARG}"
          ;;
      C)
          ACTION="create-cluster"
          ;;
      d)
          ACTION="deploy"
          ;;
      D)
          DOMAIN="${OPTARG}"
          ;;
      f)
          FILER_IP="${OPTARG}"
          ;;
      F)
          FILER_PATH="${OPTARG}"
          ;;
      h)
          print_usage
          exit 0
          ;;
      i)
          IMAGE_PREFIX="${OPTARG}"
          ;;
      m)
          MACHINE_TYPE=${OPTARG}
          ;;
      M)
          SUBDOMAIN_PFIX=${OPTARG}
          ;;
      n)
          CLUSTER_NODES=${OPTARG}
          ;;
      o)
          OAUTH_CLIENT_ID=${OPTARG}
          ;;
      O)
          OAUTH_CLIENT_SECRET=${OPTARG}
          ;;
      p)
          PUSH_IMAGE=true
          ;;
      r)
          REPOSITORY_PATH="${OPTARG}"
          ;;
      s)
          SKIP_CERTS=true
          ;;
      S)
          TRUSTED_CRT="--from-file /tmp/trusted.crt"
          ;;
      t)
          ACTION="test"
          ;;
      T)
          ACTION="teardown"
          ;;
      u)
          USE_SSL_PROXY=true
          ;;
      v)
          VERBOSE=true
          ;;
      x)
          DRY_RUN=true
          ;;
      z)
          ZONE=${OPTARG}
          ;;
      ?)
          print_usage
          exit 1
          ;;
  esac
done


ACTION=${ACTION:-'print_help'} 
ADMIN_USER=${ADMIN_USER:-''}
BUILD_TARGET=${BUILD_TARGET:-all}
CLUSTER_NAME=${CLUSTER_NAME:-tf4teams}
CLUSTER_NODES=${CLUSTER_NODES:-3}
AUTOSCALING=""
AUTOSCALING_MAX=${AUTOSCALING_MAX:-x}
if [[ "${AUTOSCALING_MAX}" =~ ^[0-9]+$ ]] && [ "${AUTOSCALING_MAX}" -ge "${CLUSTER_NODES}" ] && [ "${AUTOSCALING_MAX}" -le 32 ]; then
    AUTOSCALING="--enable-autoscaling --max-nodes ${AUTOSCALING_MAX} --min-nodes ${CLUSTER_NODES}"
fi
DOMAIN=${DOMAIN:-''}
SUBDOMAIN_PFIX=${SUBDOMAIN_PFIX:-jhub}
DRY_RUN=${DRY_RUN:-false}
SUBDOMAIN="${SUBDOMAIN_PFIX}.${DOMAIN}"
IMAGE_PREFIX=${IMAGE_PREFIX:-'cloud-solutions-images'} #used only for build action

ERROR_COUNT=0 #used in validation step will exit if > 0
FILER_IP=${FILER_IP:-''} #NFS File Server internal IP address
FILER_PATH=${FILER_PATH:-'/data'}
GCP_PROJECT=""
GCLOUD="$(which gcloud)"
DOCKER="$(which docker)"

KUBECTL="$(which kubectl)"
LOG_FILE=./output.log
LOG_OUTPUT=${LOG_OUTPUT:-false}
PUSH_IMAGE=${PUSH_IMAGE:-false}

OAUTH_CLIENT_ID=${OAUTH_CLIENT_ID:-''}
OAUTH_CLIENT_SECRET=${OAUTH_CLIENT_SECRET:-''}
MACHINE_TYPE=${MACHINE_TYPE:-'n1-standard-4'}
PROXY_HEALTH="${CLUSTER_NAME}-proxy-health"
REPOSITORY_PATH=${REPOSITORY_PATH:-''}

SINGLE_USER_IMAGE=${SINGLE_USER_IMAGE:-'tf-deepdream-su:latest'}
SKIP_CERTS=${SKIP_CERTS:-false}
SSL_TAG="${CLUSTER_NAME}-ssl" #should be able to change this for multiple deployments within the same project
TRUSTED_CRT=${TRUSTED_CRT:-''}
USE_SSL_PROXY=${USE_SSL_PROXY:-false} #requires the beta compute api
VERBOSE=${VERBOSE:-false} #prints detailed information
ZONE=${ZONE:-'us-east1-d'}
REGION="$(awk -F- '{print $1 "-" $2}' <<< ${ZONE})"

validate
# Execute the requested action
eval $ACTION
