#!/bin/bash

install_nginx() {
    sudo amazon-linux-extras install nginx1.12
    sudo systemctl start nginx
}

install_mongo() {
    case "`uname -i`" in
      x86_64|amd64)
        baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/4.4/x86_64/;;
      aarch64)
        baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/4.4/aarch64/;;
    esac
    echo "[mongodb-org-4.4]
name=MongoDB Repository
baseurl=${baseurl}
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc" | sudo tee /etc/yum.repos.d/mongodb-org-4.4.repo > /dev/null

    sudo yum install -y mongodb-org
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
metadata_expire=300" | sudo tee /etc/yum.repos.d/graviteeio.repo > /dev/null
    sudo yum -q makecache -y --disablerepo='*' --enablerepo='graviteeio'
    sudo yum install -y graviteeio-am-3x
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
    sudo amazon-linux-extras install java-openjdk11
}

main() {
    install_openjdk
    install_nginx
    install_mongo
    install_graviteeio
}

main