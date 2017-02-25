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
FROM jupyter/scipy-notebook

MAINTAINER svee@google.com
WORKDIR "/opt"
USER root

ENV CLOUDSDK_PYTHON "python2.7"
ENV HOME /root
ENV NB_USER root

RUN apt-get -qq update && apt-get install --no-install-recommends -y unzip wget git nodejs npm \
 && mkdir -p /mnt/notebooks/tensorflow  /root/.local/share/jupyter  /notebooks/datalab \
 && wget https://github.com/googledatalab/notebooks/archive/master.zip \
 && unzip master.zip && cp -nr notebooks-master/* /notebooks/datalab/ \
 && rm -rf master.zip notebooks-master \
 && wget https://dl.google.com/dl/cloudsdk/channels/rapid/google-cloud-sdk.tar.gz \
 && tar -xzf google-cloud-sdk.tar.gz && rm google-cloud-sdk.tar.gz \
 && google-cloud-sdk/install.sh --path-update=true --bash-completion=true --rc-path=/.bashrc \
 --additional-components gcloud core gsutil compute bq preview alpha beta \
 && google-cloud-sdk/bin/gcloud -q components update \
 && google-cloud-sdk/bin/gcloud config set --installation component_manager/disable_update_check true \
 && npm install -g typescript \
 && wget https://github.com/googledatalab/pydatalab/archive/master.zip \
 && unzip -q master.zip && ln -s /usr/bin/nodejs /usr/bin/node \
 && tsc --module amd --noImplicitAny --outdir pydatalab-master/datalab/notebook/static pydatalab-master/datalab/notebook/static/*.ts \
 && git clone https://github.com/apache/beam.git 
RUN /opt/conda/envs/python2/bin/pip install pydatalab-master/. beam/sdks/python/. \
   http://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-1.0.0-cp27-none-linux_x86_64.whl \
   https://storage.googleapis.com/cloud-ml/sdk/cloudml.latest.tar.gz \
   google-api-python-client psutil plotly \
 && /opt/conda/envs/python2/bin/jupyter nbextension install --py datalab.notebook --sys-prefix \
 && apt-get remove -y nodejs npm \
 && apt-get clean && rm -rf master.zip pydatalab-master python-sdk.zip incubator-beam-python-sdk /var/lib/apt/lists/* /tmp/* /var/tmp/*
 
 ENV PATH /root/.local/bin:${PATH}
 COPY jupyter_notebook_config.py /root/.jupyter/
 COPY ipython_config.py /root/.ipython/profile_default/
 COPY docker-entrypoint.sh /docker-entrypoint.sh
 RUN chmod a+rx /docker-entrypoint.sh
