#! /bin/bash

mkdir -p ngx_conf/resolvers
echo resolver $(awk 'BEGIN{ORS=" "} $1=="nameserver" {print $2}' /etc/resolv.conf) "ipv6=off;" > ngx_conf/resolvers/conf
