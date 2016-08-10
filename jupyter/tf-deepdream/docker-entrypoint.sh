#!/bin/sh
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
# Description: Starts the Jupyter web application in singleuser mode
set -e

notebook_arg=""
if [ -n "${NOTEBOOK_DIR:+x}" ]; then
    notebook_arg="--notebook-dir=${NOTEBOOK_DIR}"
    if [  "${NOTEBOOK_DIR}" != "/notebooks" ]; then
      cp -rn /notebooks/*  "${NOTEBOOK_DIR}"
    fi
fi
if [ -z ${BYPASS_SINGLE_USER} ]; then
  exec sh -c "jupyterhub-singleuser \
    --port=8888 \
    --ip=0.0.0.0 \
    --user=$JPY_USER \
    --cookie-name=$JPY_COOKIE_NAME \
    --base-url=$JPY_BASE_URL \
    --hub-prefix=$JPY_HUB_PREFIX \
    --hub-api-url=$JPY_HUB_API_URL \
    ${notebook_arg} \
    $@ 2>&1 | tee /var/log/jupyter.log"
else
  exec sh -c "jupyter notebook ${notebook_arg} $@"
fi