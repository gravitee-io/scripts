#!/bin/bash

#let script exit if a command fails
set -o errexit

#let script exit if an unsed variable is used
set -o nounset

declare GRAVITEE_PRODUCT=""
declare GRAVITEE_VERSION=""
declare GRAVITEE_ACTION=""
declare ROOT_DIR="/opt/graviteeio"
declare SYSTEM_SERVICES_DIR="/etc/systemd/system"
declare HTTPD_CONF_DIR=""
declare -r TMP_FOLDER="/tmp/graviteeio_$(date +"%Y%m%d_%H%M%S")"
declare USER="gravitee"

welcome() {
    echo
    echo -e "    _____                 _ _              _                                 \033[0m"
    echo -e "   / ____|               (_) |            (_)                                \033[0m"
    echo -e "  | |  __ _ __ __ ___   ___| |_ ___  ___   _  ___                            \033[0m"
    echo -e "  | | |_ |  __/ _  \ \ / / | __/ _ \/ _ \ | |/ _ \                           \033[0m"
    echo -e "  | |__| | | | (_| |\ V /| | ||  __/  __/_| | (_) |                          \033[0m"
    echo -e "   \_____|_|  \__,_| \_/ |_|\__\___|\___(_)_|\___/                           \033[0m"
    echo -e "                          \033[0mhttps://gravitee.io\033[0m"
    echo -e "                                                                             \033[0m"
    echo -e "                  _____ _____    _____  _       _    __                      \033[0m"
    echo -e "            /\   |  __ \_   _|  |  __ \| |     | |  / _|                     \033[0m"
    echo -e "           /  \  | |__) || |    | |__) | | __ _| |_| |_ ___  _ __ _ __ ___   \033[0m"
    echo -e "          / /\ \ |  ___/ | |    |  ___/| |/ _  | __|  _/ _ \|  __|  _   _ \  \033[0m"
    echo -e "         / ____ \| |    _| |_   | |    | | (_| | |_| || (_) | |  | | | | | | \033[0m"
    echo -e "        /_/    \_\_|   |_____|  |_|    |_|\__,_|\__|_| \___/|_|  |_| |_| |_| \033[0m"
    echo -e "                                                                             \033[0m"

    echo
}

usage() {
    echo "NAME
    $(basename "$0")  -- a program to install/remove a gravitee component
SYNOPSYS
    $(basename "$0") [-p product] [-v version] [install uninstall]
    $(basename "$0") -h
DESCRIPTION
    where:
    -v         the Gravitee.io product version
    -h         help
    install    install/upgrade a version of a component
    uninstall  uninstall a version
EXAMPLE
    gravitee-cli.sh -p apim -v 1.30.3 install
    gravitee-cli.sh -p apim uninstall
"
    exit
}

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") [$1] $2"
}

assert_user() {
    found_user=$(cat /etc/passwd | egrep -e $USER | awk -F ":" '{ print $1}')
    if [[ "$found_user" != "$USER" ]];then
        sudo useradd $USER
    else
        echo "$found_user already exists, skipping..."
    fi
}

assert_product() {
    case ${GRAVITEE_PRODUCT} in
        apim|am)  ;;
        *) echo "Unknown product [${GRAVITEE_PRODUCT}]" && usage;;
    esac
}

### Install MongoDB
# Doc: https://docs.mongodb.com/v3.6/tutorial/install-mongodb-on-amazon/#install-mongodb-community-edition
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

### Install OpenJDK
install_openjdk() {
        sudo yum install -y java-1.8.0-openjdk
}

### Install Elasticsearch
# Doc: https://www.elastic.co/guide/en/elasticsearch/reference/6.6/rpm.html#rpm-repo
install_elasticsearch() {
        echo "[elasticsearch-6.x]
name=Elasticsearch repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md" | sudo tee /etc/yum.repos.d/elasticsearch.repo > /dev/null
        sudo yum install -y elasticsearch
        sudo systemctl start elasticsearch
}

download_and_prepare_product() {
    local url=""
    local filename=""
    case ${GRAVITEE_PRODUCT} in
        apim)
            url="https://download.gravitee.io/graviteeio-apim/distributions/"
            filename="graviteeio-full-${GRAVITEE_VERSION}.zip"
            ;;
        am)
            url="https://download.gravitee.io/graviteeio-am/distributions/"
            filename="graviteeio-am-full-${GRAVITEE_VERSION}.zip"
            ;;
    esac

    local dest_file_path="${TMP_FOLDER}/${filename}"
    log "${FUNCNAME}" "Download ${GRAVITEE_PRODUCT} version ${GRAVITEE_VERSION} into ${dest_file_path}"
    mkdir -p ${TMP_FOLDER}
    wget -O ${dest_file_path} "${url}${filename}"

    log "${FUNCNAME}" "Check sha1"
    wget -nv -O ${dest_file_path}.sha1 "${url}${filename}.sha1"
    local prevdir=$PWD

    cd ${TMP_FOLDER}

    sha1sum -c ${filename}.sha1
    log "${FUNCNAME}" "Prepare"
    unzip ${filename}
    rm ${filename}
    rm ${filename}.sha1

    cd ${prevdir}
}

### Install Gravitee.io
install_graviteeio() {
    local install_dir="${ROOT_DIR}/${GRAVITEE_PRODUCT}"

    # Configure from existing configuration
    if [ -d $install_dir/.config ]
    then
        cp -fr ${install_dir}/.config/ui/constants.json ${install_dir}/ui
        cp -fr ${install_dir}/.config/api/* ${install_dir}/api/config
        cp -fr ${install_dir}/.config/gateway/* ${install_dir}/gateway/config
    fi

    #  Configure Portal
    sed -i "s#http://localhost:8083/management/#http://18.216.181.56:8083/management/#g" ${install_dir}/ui/constants.json

    # Configure Gateway

    if [ -d "APIM" ] 
    then
        # Portal custo
        install_portal_customizations

        # Custom Snaplogic extensions
        install_snaplogic_extensions
    fi

    nohup ${ROOT_DIR}/${GRAVITEE_PRODUCT}/gateway/bin/gravitee > /dev/null 2>&1 &
    nohup ${ROOT_DIR}/${GRAVITEE_PRODUCT}/api/bin/gravitee > /dev/null 2>&1 &
}

install_portal_customizations() {
    cp APIM/logo.png ${ROOT_DIR}/${GRAVITEE_PRODUCT}/ui/themes/assets/logo.png
    cp APIM/constants.json ${ROOT_DIR}/${GRAVITEE_PRODUCT}/ui/constants.json
    cp APIM/background.jpg ${ROOT_DIR}/${GRAVITEE_PRODUCT}/ui/themes/assets/background.jpg
    cp APIM/poc-theme.json ${ROOT_DIR}/${GRAVITEE_PRODUCT}/ui/themes/poc-theme.json
}

install_snaplogic_extensions() {
    cp APIM/gravitee-services-snaplogic-integration-1.0.0-SNAPSHOT.zip ${ROOT_DIR}/${GRAVITEE_PRODUCT}/api/plugins
    export GRAVITEE_SERVICES_SNAPLOGIC_ENABLED=true
    export GRAVITEE_SERVICES_SNAPLOGIC_URL=https://elastic.snaplogic.com:443/api/1/rest/slsched/feed/ZodiacDigitalTransformationDev/Sedex/Linus_APIManagement/01_ReceiveGravitee_Task
    export GRAVITEE_SERVICES_SNAPLOGIC_AUTHENTICATION_BEARER=MVqeXmyI22kyZ3FyxqRRTm5mcde8B0Q2
}

### Install Node HTTP server
install_http_server() {
        curl --silent --location https://rpm.nodesource.com/setup_13.x | sudo bash
        sudo yum install -y nodejs
        sudo npm install http-server -g
        cd ${ROOT_DIR}/${GRAVITEE_PRODUCT}/ui
        nohup http-server -p 80 > /dev/null 2>&1 &
}

deploy_services() {
    log "${FUNCNAME}" "copy services"

    case ${GRAVITEE_PRODUCT} in
        apim)
            wget -P ${SYSTEM_SERVICES_DIR} https://raw.githubusercontent.com/gravitee-io/scripts/master/rpm/services/apim/gravitee-apim-gateway.service
            wget -P ${SYSTEM_SERVICES_DIR} https://raw.githubusercontent.com/gravitee-io/scripts/master/rpm/services/apim/gravitee-apim-api.service
            ;;
        am)
            wget -P ${SYSTEM_SERVICES_DIR} https://raw.githubusercontent.com/gravitee-io/scripts/master/rpm/services/am/gravitee-am-gateway.service
            wget -P ${SYSTEM_SERVICES_DIR} https://raw.githubusercontent.com/gravitee-io/scripts/master/rpm/services/am/gravitee-am-api.service
            ;;
    esac
}

stop_services() {
    if [[ -f ${SYSTEM_SERVICES_DIR}/gravitee-${GRAVITEE_PRODUCT}-api.service ]]; then
        log "${FUNCNAME}" "Stop Gravitee.io ${GRAVITEE_PRODUCT} service gravitee-${GRAVITEE_PRODUCT}-api"
        if [[ "${DEBUG}" != "true" ]]; then
            sudo systemctl stop gravitee-${GRAVITEE_PRODUCT}-api
        fi
    fi

    if [[ -f ${SYSTEM_SERVICES_DIR}/gravitee-${GRAVITEE_PRODUCT}-gateway.service ]]; then
        log "${FUNCNAME}" "Stop Gravitee.io ${GRAVITEE_PRODUCT} service gravitee-${GRAVITEE_PRODUCT}-gateway"
        if [[ "${DEBUG}" != "true" ]]; then
            sudo systemctl stop gravitee-${GRAVITEE_PRODUCT}-gateway
        fi
    fi
}

#stop_services() {
    # Stop APIM processes
#    ps aux | grep [g]raviteeio-gateway | awk 'NR==1{print $2}'  | xargs -r kill -9
#    ps aux | grep [g]raviteeio-management-api | awk 'NR==1{print $2}'  | xargs -r kill -9
#}

copy_config() {
    local install_dir="${ROOT_DIR}/${GRAVITEE_PRODUCT}"

    if [ -d $install_dir ]
    then
        mkdir -p ${install_dir}/.config/ui ; mkdir -p ${install_dir}/.config/api ; mkdir -p ${install_dir}/.config/gateway
        cp -R ${install_dir}/ui/constants.json ${install_dir}/.config/ui/constants.json
        cp -R ${install_dir}/api/config/* ${install_dir}/.config/api
        cp -R ${install_dir}/gateway/config/* ${install_dir}/.config/gateway
    fi
}

install() {
    [[ -z "$GRAVITEE_VERSION" ]] && usage
    assert_product
    assert_user
    
    copy_config

    download_and_prepare_product

    stop_services

    uninstall

    log "${FUNCNAME}" "Install Gravitee.io ${GRAVITEE_PRODUCT}"
    local install_dir="${ROOT_DIR}/${GRAVITEE_PRODUCT}"
    mkdir -p ${install_dir}
    cp -R ${TMP_FOLDER}/*/* ${install_dir}

    case ${GRAVITEE_PRODUCT} in
        apim)
            ln -sf ${install_dir}/graviteeio-management-ui-${GRAVITEE_VERSION}/   ${install_dir}/ui
            ln -sf ${install_dir}/graviteeio-management-api-${GRAVITEE_VERSION}/  ${install_dir}/api
            ln -sf ${install_dir}/graviteeio-gateway-${GRAVITEE_VERSION}/         ${install_dir}/gateway
            ;;
        am)
            ln -sf ${install_dir}/graviteeio-am-management-ui-${GRAVITEE_VERSION}/   ${install_dir}/ui
            ln -sf ${install_dir}/graviteeio-am-management-api-${GRAVITEE_VERSION}/  ${install_dir}/api
            ln -sf ${install_dir}/graviteeio-am-gateway-${GRAVITEE_VERSION}/         ${install_dir}/gateway
            ;;
    esac

    install_graviteeio
    install_mongo
    install_openjdk
    install_elasticsearch
    install_http_server

    log "${FUNCNAME}" "Install Gravitee.io systemd services"
    deploy_services
}

uninstall() {
    assert_product
    stop_services

    local install_dir="${ROOT_DIR}/${GRAVITEE_PRODUCT}"

    log "${FUNCNAME}" "Uninstall ui from ${ROOT_DIR}/${GRAVITEE_PRODUCT}"
    rm -f ${install_dir}/ui
    log "${FUNCNAME}" "Uninstall api from ${ROOT_DIR}/${GRAVITEE_PRODUCT}"
    rm -f ${install_dir}/api
    log "${FUNCNAME}" "Uninstall gateway from ${ROOT_DIR}/${GRAVITEE_PRODUCT}"
    rm -f ${install_dir}/gateway
}

##################################################
# Main
##################################################

while getopts 'dh:p:v:' o
do
    case $o in
    p) GRAVITEE_PRODUCT=$OPTARG ;;
    v) GRAVITEE_VERSION=$OPTARG ;;
    d) DEBUG="true" ;;
    h|*) usage ;;
    esac
done
shift $((OPTIND-1))
GRAVITEE_ACTION=$@

welcome

case ${GRAVITEE_ACTION} in
    install) install ;;
    uninstall) uninstall ;;
    *) usage ;;
esac