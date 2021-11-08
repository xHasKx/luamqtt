#!/bin/bash

set -e

PATH=/opt/openresty/nginx/sbin:$PATH
export PATH
nginx -p "$(pwd)" -c conf/nginx.conf

# since this is an example, start tailing the logs
touch logs/error.log
tail -F logs/error.log
