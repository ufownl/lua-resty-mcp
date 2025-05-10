#! /bin/bash

CA_CERTS=(
  "/etc/ssl/certs/ca-certificates.crt"
  "/etc/pki/tls/certs/ca-bundle.crt"
  "/etc/ssl/ca-bundle.pem"
  "/etc/pki/tls/cacert.pem"
  "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem"
  "/etc/ssl/cert.pem"
)

mkdir -p ngx_conf/lua_ssl
for file in "${CA_CERTS[@]}"
do
  if [ -f "${file}" ]
  then
    echo -e "lua_ssl_trusted_certificate ${file};\nlua_ssl_verify_depth 2;" > ngx_conf/lua_ssl/conf
    break
  fi
done
