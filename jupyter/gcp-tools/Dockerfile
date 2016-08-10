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

FROM b.gcr.io/tensorflow/tensorflow:latest

WORKDIR "/opt"

RUN apt-get -qq update && apt-get install --no-install-recommends -y unzip wget python3-pip \
    git nodejs npm build-essential libssl-dev libffi-dev python-dev python3-dev \
    && mkdir -p /mnt/notebooks/tensorflow  /root/.local/share/jupyter  /notebooks/datalab \
    && wget https://github.com/googledatalab/notebooks/archive/master.zip \
    && unzip master.zip && cp -nr notebooks-master/* /notebooks/datalab/ \
    && rm -rf master.zip notebooks-master \
    && pip install --upgrade 'requests[security]' && pip install --upgrade pip \
    && pip install --upgrade ggplot==0.6.8  \
    jinja2 'notebook>=4.1' protobuf==3.0.0b2.post2 \
    requests scikit-learn==0.17.1 \
    seaborn==0.7.0  statsmodels==0.6.1 sympy==0.7.6.1 terminado tornado \
    && python3 -m pip install ipykernel \
    && python3 -m ipykernel install --user \
    && wget -q https://goo.gl/CFhAZF -O /usr/local/bin/jupyterhub-singleuser \
    && chmod 755 /usr/local/bin/jupyterhub-singleuser \
    && wget https://dl.google.com/dl/cloudsdk/channels/rapid/google-cloud-sdk.tar.gz \
    && tar -xzf google-cloud-sdk.tar.gz && rm google-cloud-sdk.tar.gz \
    && google-cloud-sdk/install.sh --path-update=true --bash-completion=true --rc-path=/.bashrc \
    --additional-components gcloud core gsutil compute bq preview alpha beta \
    && google-cloud-sdk/bin/gcloud -q components update \
    && google-cloud-sdk/bin/gcloud config set --installation component_manager/disable_update_check true  \
    && npm install -g typescript \
    && wget https://github.com/googledatalab/pydatalab/archive/master.zip \
    && unzip master.zip && ln -s /usr/bin/nodejs /usr/bin/node \
    && tsc --module amd --noImplicitAny --outdir pydatalab-master/datalab/notebook/static pydatalab-master/datalab/notebook/static/*.ts \
    && pip install pydatalab-master/. https://github.com/GoogleCloudPlatform/DataflowPythonSDK/archive/v0.2.7.tar.gz \
    && jupyter nbextension install --py datalab.notebook --sys-prefix \
    && apt-get remove -y libssl-dev libffi-dev nodejs npm \
    && apt-get clean && rm -rf master.zip pydatalab-master /var/lib/apt/lists/* /tmp/* /var/tmp/*


COPY jupyter_notebook_config.py /root/.jupyter/
COPY ipython_config.py /root/.ipython/profile_default/
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod a+rx /docker-entrypoint.sh  

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD [""]

