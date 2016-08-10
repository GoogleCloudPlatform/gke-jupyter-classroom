#!/bin/bash
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
set -e
#allows the use of a remote file system
SHARED_PATH=${SHARED_PATH:-'/opt'}

if [ ! -f ${SHARED_PATH}/cookie.secret ]; then
  #generate unique keys for this deployment
  openssl rand -hex 1024 > $SHARED_PATH/configproxy.token
  openssl rand -hex 32 > $SHARED_PATH/cookie.secret
fi
cd ${SHARED_PATH}
export JPY_COOKIE_SECRET="$(cat ${SHARED_PATH}/cookie.secret)"
export CONFIGPROXY_AUTH_TOKEN="$(cat ${SHARED_PATH}/configproxy.token)"
#export KUBE_TOKEN='' #"$(cat /run/secrets/kubernetes.io/serviceaccount/token)"
exec sh -c "jupyterhub --no-ssl -f /srv/jupyterhub/jupyterhub_config.py 2>&1 | tee /var/log/jupyterhub2.log"