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
    sudo service elasticsearch start
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
    sudo yum install -y graviteeio-apim-3x
    sudo service graviteeio-apim-gateway start
    sudo service graviteeio-apim-rest-api start
    http_response=$(curl -w "%{http_code}" -o /tmp/curl_body "http://169.254.169.254/latest/meta-data/public-ipv4")
    if [ $http_response == "200" ]; then
        sudo sed -i -e "s/localhost/$(cat /tmp/curl_body)/g" /opt/graviteeio/apim/management-ui/constants.json
        sudo sed -i -e "s;/portal;http://$(cat /tmp/curl_body):8083/portal;g" /opt/graviteeio/apim/portal-ui/assets/config.json
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
    install_elasticsearch
    install_graviteeio
}

main