#!/bin/bash

set -e

PATH=/opt/openresty/nginx/sbin:$PATH
export PATH
nginx -p `pwd`/ -c conf/nginx.conf

