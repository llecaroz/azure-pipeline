#!/bin/bash

function find_bridge_name {
  for i in $(docker network ls --format "{{.Name}}") 
  do
    name=$(docker network inspect --format "{{json .}}" $i | jq -r 'select(.Options."com.docker.network.bridge.default_bridge"== "true")|.Options."com.docker.network.bridge.name"')
    if [ -n "${name}" ]; then
      echo $name
      return
    fi
  done

  echo docker0
}
bridge_ip=$(ip addr show $(find_bridge_name) | awk -F "[,/ ]+" '/inet /{print $3}')
proxy_port=8181
access_log=$PWD/access_log
proxy_conf=./proxy

rm -rf $access_log

cat << EOF  | tee $proxy_conf > /dev/null
http_port $bridge_ip:$proxy_port
http_port 127.0.0.1:$proxy_port
cache deny all
cache_dir null /dev/null
pid_filename /dev/null
cache_log /dev/null
cache_store_log /dev/null
access_log $access_log
strip_query_terms off
http_access allow all
# allow all requests
# acl all src all
EOF

sudo apt-get -yq install squid
sudo service squid stop
squid -N -f $proxy_conf &
squid_pid=$!
timeout 15 bash -c "until echo > /dev/tcp/$bridge_ip/$proxy_port; do sleep 0.5; done"

curl --proxy $bridge_ip:$proxy_port https://www.microsoft.com -o index.html

kill -2 $squid_pid
cat index.html
cat $access_log
