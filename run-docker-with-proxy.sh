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
access_log=./logs/access_log

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
squid -f ./proxy.conf
echo return value of squid is: $?
squid -k check -a $proxy_port
echo return value of squid check is: $?
