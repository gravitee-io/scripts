#!/bin/bash

install_nginx() {
    sudo yum install -y nginx
}

install_mongo() {
    echo "[mongodb-org-4.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/4.4/x86_64/
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

    ui_port=$(sudo semanage port -l | grep 8094 | wc -l)
    if [[ "$ui_port" -eq 0 ]]
    then
        sudo semanage port -a -t http_port_t -p tcp 8094
    else
        sudo semanage port -m -t http_port_t -p tcp 8094
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
    install_graviteeio
}

main