#!/bin/bash

install_nginx() {
    sudo yum install -y epel-release policycoreutils-python-utils
    sudo yum install -y nginx
}

install_mongo() {
    echo "[mongodb-org-3.6]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2013.03/mongodb-org/3.6/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.6.asc" | sudo tee /etc/yum.repos.d/mongodb-org-3.6.repo > /dev/null

    sudo yum install -y mongodb-org
    sudo systemctl start mongod
}

install_elasticsearch() {
    echo "[elasticsearch-7.x]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md" | sudo tee /etc/yum.repos.d/elasticsearch.repo > /dev/null
    sudo yum install -y elasticsearch
    sudo systemctl start elasticsearch
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
metadata_expire=300" | sudo tee /etc/yum.repos.d/graviteeio.repo > /dev/null
    sudo yum -q makecache -y --disablerepo='*' --enablerepo='graviteeio'
    sudo yum install -y graviteeio-apim
    sudo systemctl daemon-reload
    sudo systemctl start graviteeio-apim-gateway graviteeio-apim-management-api
#    sudo semanage port -a -t http_port_t -p tcp 8084
    sudo semanage port -m -t http_port_t -p tcp 8084
    sudo systemctl restart nginx
}

install_openjdk() {
    sudo yum install -y java-11-openjdk-devel
}

main() {
    install_openjdk
    install_nginx
    install_mongo
    install_elasticsearch
    install_graviteeio
}

main