#!/bin/bash

install_nginx() {
    sudo yum install nginx
    sudo service nginx start
}

install_mongo() {
    echo "[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2013.03/mongodb-org/4.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc" | sudo tee /etc/yum.repos.d/mongodb-org-4.4.repo > /dev/null

    sudo yum install -y mongodb-org
    sudo service mongod start
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
    sudo service graviteeio-am-gateway start
    sudo service graviteeio-am-management-api start
    sudo sed -i -e "s/4200/8094/g" /opt/graviteeio/am/management-ui/constants.json
    http_response=$(curl -w "%{http_code}" -o /tmp/curl_body "http://169.254.169.254/latest/meta-data/public-ipv4")
    if [ $http_response == "200" ]; then
        sudo sed -i -e "s/localhost/$(cat /tmp/curl_body)/g" /opt/graviteeio/am/management-ui/constants.json
    fi

    sudo service nginx restart
}

install_openjdk() {
    sudo yum install java-1.8.0-openjdk -y
    sudo /usr/sbin/alternatives --set java /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/java
    sudo /usr/sbin/alternatives --set javac /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/javac
    sudo yum remove java-1.7.0-openjdk -y
}

main() {
    install_openjdk
    install_nginx
    install_mongo
    install_graviteeio
}

main