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
# Description: Extends the JupyterHub image and installs Google cloud sdk
#              and some additional custom configurations for Container Engine
#              Google OAuth2 authentication and Kubernetes Spawner Code
#
#

FROM jupyterhub/jupyterhub:latest

WORKDIR /opt
RUN apt-get -qq update && apt-get install -y nfs-common \
    && pip install requests-futures git+git://github.com/jupyterhub/oauthenticator.git \
                   git+git://github.com/sveesible/jupyterhub-kubernetes-spawner.git \
    && openssl rand -hex 1024 > configproxy.token \
    && openssl rand -hex 32 > cookie.secret \
    && mkdir -p /mnt/jupyterhub \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY jupyterhub_config.py /srv/jupyterhub/jupyterhub_config.py
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod a+rx /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD [""]
