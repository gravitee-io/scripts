#!/bin/bash

install_nginx() {
    sudo zypper addrepo -G -t yum -c 'http://nginx.org/packages/sles/15' nginx
    sudo rpm --import http://nginx.org/keys/nginx_signing.key
    sudo zypper -n install nginx
}

install_mongo() {
    sudo rpm --import https://www.mongodb.org/static/pgp/server-6.0.asc
    sudo zypper addrepo --gpgcheck "https://repo.mongodb.org/zypper/suse/15/mongodb-org/6.0/x86_64/" mongodb
    sudo zypper -n install mongodb-org
    sudo systemctl start mongod
}

install_graviteeio() {
    echo "[graviteeio]
name=graviteeio
baseurl=https://packagecloud.io/graviteeio/rpms/el/7/\$basearch
gpgcheck=0
enabled=1
gpgkey=https://packagecloud.io/graviteeio/rpms/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
type=rpm-md" | sudo tee /etc/zypp/repos.d/graviteeio.repo > /dev/null
    sudo zypper -n install graviteeio-am-4x
    sudo systemctl daemon-reload
    sudo systemctl start graviteeio-am-gateway graviteeio-am-management-api
    sudo sed -i -e "s/4200/8094/g" /opt/graviteeio/am/management-ui/constants.json
    http_response=$(curl -w "%{http_code}" -o /tmp/curl_body "http://169.254.169.254/latest/meta-data/public-ipv4")
    if [ $http_response == "200" ]; then
        sudo sed -i -e "s/localhost/$(cat /tmp/curl_body)/g" /opt/graviteeio/am/management-ui/constants.json
    fi
    sudo systemctl restart nginx
}

install_openjdk() {
  version=$(cut -d "=" -f2 <<< `cat /etc/os-release | grep VERSION_ID` | tr -d '"')
  if [[ $version = 12* ]]; then
    sudo zypper addrepo https://download.opensuse.org/repositories/Java:Factory/SLE_12_SP5/Java:Factory.repo
    sudo zypper --gpg-auto-import-keys ref
    sudo zypper refresh
  fi

  sudo zypper -n install java-17-openjdk
}

main() {
    install_openjdk
    install_nginx
    install_mongo
    install_graviteeio
}

main