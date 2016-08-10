# Copyright 2016 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Description: Specialized configuration for JupyterHub on Google Container Engine
#
#
c = get_config()

import os

c.JupyterHub.log_level = os.environ['JHUB_LOG_LEVEL']

c.JupyterHub.proxy_api_ip = '0.0.0.0'
c.JupyterHub.hub_ip = '0.0.0.0'
c.JupyterHub.extra_log_file = '/var/log/jupyterhub.log'
#allows admin to log in to user instances
c.JupyterHub.admin_access = True
c.JupyterHub.authenticator_class = 'oauthenticator.GoogleOAuthenticator'
c.Authenticator.admin_users = admin = set()
admin.update(os.environ['ADMIN_USERS'].split(','))
c.Authenticator.whitelist = whitelist = set()
whitelist.update(os.environ['OAUTH_WHITELIST'].split(','))

c.GoogleOAuthenticator.client_id = os.environ['OAUTH_CLIENT_ID']
c.GoogleOAuthenticator.client_secret = os.environ['OAUTH_CLIENT_SECRET']
c.GoogleOAuthenticator.oauth_callback_url = os.environ['OAUTH_CALLBACK_URL']
c.JupyterHub.spawner_class = 'kubernetespawner.Kubernetespawner'
c.Kubernetespawner.start_timeout = 45
c.Kubernetespawner.debug = os.environ['JHUB_SPWN_DEBUG'] == "TRUE"
c.Kubernetespawner.pod_name_template = 'jupyter-{username}'
c.Kubernetespawner.hub_ip_connect = os.environ['KSPAWN_HUB_IP']
c.Kubernetespawner.kube_namespace = 'jupyterhub'
c.Kubernetespawner.singleuser_image_spec = os.environ['KUBESPAWN_IMAGE']
c.Kubernetespawner.use_options_form = True
c.Kubernetespawner.cpu_limit = os.environ['KUBESPAWN_CPU_LIMIT']
c.Kubernetespawner.cpu_request = os.environ['KUBESPAWN_CPU_REQUEST']
c.Kubernetespawner.mem_limit = os.environ['KUBESPAWN_MEM_LIMIT']
c.Kubernetespawner.mem_request = os.environ['KUBESPAWN_MEM_REQUEST']
c.Kubernetespawner.notebook_dir = '/mnt/notebooks'
c.Kubernetespawner.create_user_volume_locally = True
c.Kubernetespawner.volumes = [ {"name": "{username}-nfs", "nfs": {"path": os.environ['KUBESPAWN_NFS_PATH'] ,"server": os.environ['KUBESPAWN_NFS_SERVER']}}]
c.Kubernetespawner.volume_mounts = [ {"name": "{username}-nfs", "mountPath": "/mnt/notebooks"} ]
