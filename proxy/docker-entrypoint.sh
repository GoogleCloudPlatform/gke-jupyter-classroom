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
# limitations under the License
set -e
#This script exists because envsubst is too aggressive and pulls out $VAR along with ${VAR}, 
#But Nginx likes to use $VAR for it's own values

if [ -z ${NG_CONF_INPUT} ] || [ ! -f "${NG_CONF_INPUT}" ] || [ -z ${NG_CONF_OUTPUT} ]; then
	echo "Error validating input file make sure the configMap volume " \
	"is mapped properly and the NG_CONF_PATH and NG_CONF_INPUT NG_CONF_OUTPUT variables are set" \
	| tee  -a /var/log/nginx-startup.log
	exit 1
fi

#run the substitution test to verify all variables get swapped
read foo <<< $(perl -p -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' < yourfile.txt | grep -Po '\$\{.*\}') 
if [[ -n $foo && ! ${foo+x} ]]; then
	echo "Error values not substituted check your Pod's ENV Variables are set: ${foo}" | tee  -a /var/log/nginx-startup.log
	exit 1
else
	perl -p -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' < "${NG_CONF_PATH}/${NG_CONF_INPUT}" > "${NG_CONF_OUTPUT}"
fi

 exec sh -c "/usr/sbin/nginx -g 'daemon off;' -c ${NG_CONF_OUTPUT}"