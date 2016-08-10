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
# limitations under the License
#
# Description: K8s ConfigMap Based Nginx Container
#   A generic Nginx container that reads it's config from K8s ConfigMap volume
#   and dynamically insert ENV values from ConfigMap

FROM nginx:latest
#These are the necessary ENV Variables in the Pod manifest
#ENV NG_CONF_INPUT="/mnt/config/nginx.conf"
#ENV NG_CONF_OUTPUT="/etc/nginx/nginx.conf"


ADD docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod a+rx /docker-entrypoint.sh \
	&& mkdir -p /mnt/secure /mnt/config /mnt/extra

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD [""]