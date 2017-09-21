Create Jupyter Classroom environment with Google Container Engine
====================
`gke-jupyter-classroom.sh`
Shell script for creating and managing the Container Engine Cluster and Cloud Platform Networking Components

## Features
- Build and publish JupyterHub, Nginx and Jupyter Docker images to GKE Private Repository
- Create Kubernetes Cluster on Container Engine with AutoScaling
- Auto configures SSL, Kubernetes services, load-balancing, and firewall configurations
- Use Google Authentication for users
- Use custom Domain Name or xip.io domain
- Users can select from multiple container configurations in JupyterHub
- Teardown cluster resources quickly

## Requirements
- Launch with Google Cloud Shell in Cloud Platform project.
- Preconfigure a Compute Engine VM running as an NFS Server as outlined in the tutorial:
 https://cloud.google.com/solutions/using-tensorflow-jupyterhub-classrooms


## Usage
./gke-jupyter-classroom.sh [ options ] < command> 

### Examples

  - build and push all the containers to your repository with the my-images image prefix path

  `./gke-jupyter-classroom.sh --push-image --image-prefix my-images build all` 
  - short notation
  `./gke-jupyter-classroom.sh -pi my-images -b all`

  - create and deploy to a new cluster 

  `./gke-jupyter-classroom.sh --cluster-name jupyterhub1 --autoscale-nodes 6 --nodes 1 \
       --filer-path /data --filer-ip 10.240.0.6 --image-prefix my-images \
	   --admin-user youremail@gmail.com deploy`
  
  - teardown the environment
  `./gke-jupyter-classroom.sh --cluster-name jupyterhub1  teardown`
  

### Commands:

- create-cluster ---        Only create a cluster with given name

- deploy         ---        Deploy the solution to Container Engine

- teardown       ---        Remove the solution from Cloud Platform

- commands       ---        List available commands

- options        ---        list available options


### Options:

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
     ***NOTE that this field should not be changed. /data is the only value that works with the 
        Launcher that creates the filer server Specify the file path on the NFS file server that 
	will be mounted as the root JupyterHub directory. default is /data
  
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

   -s, --skip-certs
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
    
 
### Notes

IF the Filer VM is not mounting correctly in your pods, SSH into the Filer VM and run `sudo showmounts -e localhost` and verify that it says something like this:
`Export list for localhost:
/data 127.0.0.1,10.0.0.0/8`

If the cluster is created with the default instance type and only 1 node, the default settings for memory and cpu requests will be too high to deploy a single Jupyter instance for a user. In the JupyterHub webform you can specify the following into the Environment Variables text area:
`cpu_request=100m
memory_request=100Mi`

The script must be run with sufficient privileges from Google Cloud Shell, with the Compute Engine API and Container Engine API's enabled.

The Google SSL Proxy network feature (currently in Beta) is available to use instead of the Nginx proxy.

The teardown command will not remove the cluster or the public static IP, but will print the commands you will need to execute manually
to complete the teardown.  This is useful in troubleshooting, so that you do not have to recreate the cluster and configurations that
are dependent on the public IP

You can specify your own domain, and provide your own trusted SSL certificates.  If you do not, then xip.io will be used for a domain name, 
and a self signed SSL certificate will be generated, which will prompt the users with an ignorable security warning in their browser. 

###License
 Copyright 2016 Google Inc. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
      http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS-IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

This is not an official Google product.
