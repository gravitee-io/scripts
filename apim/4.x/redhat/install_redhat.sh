#!/bin/bash

install_nginx() {
    sudo yum install -y nginx
}

install_mongo() {
    case "`uname -i`" in
      x86_64|amd64)
        baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/6.0/x86_64/;;
      aarch64)
        baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/6.0/aarch64/;;
    esac
    echo "[mongodb-org-6.0]
name=MongoDB Repository
baseurl=${baseurl}
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc" | sudo tee /etc/yum.repos.d/mongodb-org-6.0.repo > /dev/null

    sudo yum install -y mongodb-org
    sudo systemctl start mongod
}

install_elasticsearch() {
    echo "[elastic-8.x]
name=Elastic repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=0
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md" | sudo tee /etc/yum.repos.d/elasticsearch.repo > /dev/null
    sudo yum install -y elasticsearch
    sudo sed "0,/xpack.security.enabled:.*/s/xpack.security.enabled:.*/xpack.security.enabled: false/" -i /etc/elasticsearch/elasticsearch.yml
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
    sudo yum install -y graviteeio-apim-4x
    sudo systemctl daemon-reload
    sudo systemctl start graviteeio-apim-gateway graviteeio-apim-rest-api
    http_response=$(curl -w "%{http_code}" -o /tmp/curl_body "http://169.254.169.254/latest/meta-data/public-ipv4")
    if [ $http_response == "200" ]; then
        sudo sed -i -e "s/localhost/$(cat /tmp/curl_body)/g" /opt/graviteeio/apim/management-ui/constants.json
        sudo sed -i -e "s;/portal;http://$(cat /tmp/curl_body):8083/portal;g" /opt/graviteeio/apim/portal-ui/assets/config.json
    fi

    ui_port=$(sudo semanage port -l | grep 8084 | wc -l)
    if [[ "$ui_port" -eq 0 ]]
    then
        sudo semanage port -a -t http_port_t -p tcp 8084
    else
        sudo semanage port -m -t http_port_t -p tcp 8084
    fi

    portal_port=$(sudo semanage port -l | grep 8085 | wc -l)
    if [[ "$portal_port" -eq 0 ]]
    then
        sudo semanage port -a -t http_port_t -p tcp 8085
    else
        sudo semanage port -m -t http_port_t -p tcp 8085
    fi

    sudo systemctl restart nginx
}

install_openjdk() {
    sudo yum install -y java-17-openjdk-devel
}

install_tools() {
    os=`cat /etc/redhat-release  | awk '{ print tolower($1) }'`
    version=$(awk -F'=' '/VERSION_ID/{ gsub(/"/,""); print $2}' /etc/os-release | cut -d. -f1)
    echo "Detect version: $os/$version"

    if [[ "$os" == "centos" && "$version" -eq 8 ]]
    then
        echo "Update Centos Stream"
        sudo sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
        sudo sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
        sudo yum update -y
    fi

    if [[ "$version" -lt 8 ]]
    then
        echo "Install specific tools for RHEL < 8"
        sudo yum install -y epel-release
    fi

    sudo yum install -y policycoreutils-python-utils
}

main() {
    install_tools
    install_openjdk
    install_nginx
    install_mongo
    install_elasticsearch
    install_graviteeio
}

main