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
proxy_port=8080
access_log=$PWD/access_log

cat << EOF  | tee ./proxy.conf > /dev/null
http_port $bridge_ip:$proxy_port
http_port 127.0.0.1:$proxy_port
cache deny all
cache_dir null /dev/null
pid_filename /dev/null
cache_log /dev/null
cache_store_log /dev/null
access_log $access_log
strip_query_terms off
# allow all requests
acl all src all
http_access allow all
EOF

cat ./proxy.conf
sudo apt-get -yq install squid
squid -f ./proxy.conf
echo return value of squid is: $?

squid -k check -a $proxy_port
echo 1- return value of squid check is: $?
squid -k check -a 8888
echo 2 - return value of squid check is: $?
echo final of final end
curl --proxy 127.0.0.1:$proxy_port curl https://www.microsoft.com -o index.html
cat $access_log
echo acccess log above
