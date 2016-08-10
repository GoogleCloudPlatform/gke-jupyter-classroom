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
# Description: this image extends basic tensorFlow and adds the DeepDream 
#              and JupyterHub related components
#
# TODO: the JupyterHub singleuser script has moved recently in a pre-release version
#       this will require a pip3 install JupyterHub which is totally overkill for one script

FROM b.gcr.io/tensorflow/tensorflow:latest

WORKDIR "/notebooks"

RUN apt-get -qq update && apt-get install -y zip wget python3-pip nfs-common \
	&& pip3 install --upgrade pip && pip3 install requests jinja2 tornado 'notebook>=4.1' terminado \
	&& pip install --upgrade numpy \
	&& curl -O https://storage.googleapis.com/download.tensorflow.org/models/inception5h.zip \
	&& unzip -qo inception5h.zip \
	&& rm inception5h.zip \
    && mkdir -p /mnt/notebooks \
	&& wget -q https://raw.githubusercontent.com/tensorflow/tensorflow/master/tensorflow/examples/tutorials/deepdream/deepdream.ipynb \
    && wget -q https://raw.githubusercontent.com/tensorflow/tensorflow/master/tensorflow/examples/tutorials/deepdream/pilatus800.jpg \
	&& wget -q https://goo.gl/CFhAZF -O /usr/local/bin/jupyterhub-singleuser \
	&& chmod 755 /usr/local/bin/jupyterhub-singleuser \
	&& apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
	

COPY jupyter_notebook_config.py /root/.jupyter/
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod a+rx /docker-entrypoint.sh 

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD [""]
