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

get_current_public_ip() {
  local public_ip

  #case of an Azure VM
  public_ip="$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/network/interface?api-version=2021-02-01&format=json" | jq -r '.[].ipv4.ipAddress[].publicIpAddress')"
  if echo -n "${public_ip}" | grep -q -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
  then
    echo "${public_ip}"
    return 0
  fi

  #case of an AWS EC2 VM
  public_ip="$(curl -s "http://169.254.169.254/latest/meta-data/public-ipv4")"
  if echo -n "${public_ip}" | grep -q -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
  then
    echo "${public_ip}"
    return 0
  fi

  #generic case
  public_ip="$(curl -s 'https://ipv4.seeip.org')"
  if echo -n "${public_ip}" | grep -q -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
  then
    echo "${public_ip}"
    return 0
  fi

  return 1
}

configure_frontend(){
  local public_ip="$1"
  if [[ -z "${public_ip}" ]]
  then
    echo "Missing IP argument." >&2
    return 1
  fi
  sudo sed -i "/\"baseURL\": /{s#\"baseURL\": \".*\"#\"baseURL\": \"http://${public_ip}:8083/management\"#}" /opt/graviteeio/apim/management-ui/constants.json
  sudo sed -i "/\"baseURL\": /{s#\"baseURL\": \".*\"#\"baseURL\": \"http://${public_ip}:8083/portal\"#}" /opt/graviteeio/apim/portal-ui/assets/config.json
  sudo sed -i "/^#portal:/c\portal:\n  url: \"http://${public_ip}:8085\"" /opt/graviteeio/apim/graviteeio-apim-rest-api/config/gravitee.yml
}

install_graviteeio() {
    echo "[graviteeio]
name=graviteeio
baseurl=https://packagecloud.io/graviteeio/rpms/el/7/\$basearch
gpgcheck=1
repo_gpgcheck=1
enabled=1
gpgkey=https://packagecloud.io/graviteeio/rpms/gpgkey,https://packagecloud.io/graviteeio/rpms/gpgkey/graviteeio-rpms-319791EF7A93C060.pub.gpg
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300" | sudo tee /etc/yum.repos.d/graviteeio.repo > /dev/null
    sudo yum -q makecache -y --disablerepo='*' --enablerepo='graviteeio'
    sudo yum install -y graviteeio-apim-4x
    sudo systemctl daemon-reload

    echo "configure frontend"
    local public_ip
    if public_ip="$(get_current_public_ip)"
    then
      echo "Public IP detected: ${public_ip}"
      configure_frontend "${public_ip}"
    else
      echo "Public IP not found, configure with localhost"
      configure_frontend "localhost"
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

    sudo systemctl start graviteeio-apim-gateway graviteeio-apim-rest-api
    sudo systemctl restart nginx

    # @see: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/configuring_and_managing_networking/using-and-configuring-firewalld_configuring-and-managing-networking#customizing-firewall-settings-for-a-specific-zone-to-enhance-security_working-with-firewalld-zones
    if (command -v firewall-cmd > /dev/null) && ! (sudo firewall-cmd --list-ports | grep -q '8082-8085/tcp')
    then
      echo "firewall detected - open port range: 8082-8085/tcp"
      sudo firewall-cmd --add-port=8082-8085/tcp
    fi
}

install_openjdk() {
    sudo yum install -y java-21-openjdk-devel
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