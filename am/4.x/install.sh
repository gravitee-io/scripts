#!/bin/bash

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

unknown_os ()
{
  echo "Unfortunately, your operating system distribution and version are not supported by this script."
  echo
  echo "Please email contact@graviteesource.com and let us know if you run into any issues."
  exit 1
}

detect_os ()
{
  if [[ ( -z "${os}" ) && ( -z "${dist}" ) ]]; then
    if [ -e /etc/os-release ]; then
      . /etc/os-release
      os=${ID}
      if [ "${os}" = "poky" ]; then
        dist=`echo ${VERSION_ID}`
      elif [ "${os}" = "sles" ]; then
        dist=`echo ${VERSION_ID}`
      elif [ "${os}" = "opensuse" ]; then
        dist=`echo ${VERSION_ID}`
      elif [ "${os}" = "opensuse-leap" ]; then
        os=opensuse
        dist=`echo ${VERSION_ID}`
      else
        dist=`echo ${VERSION_ID} | awk -F '.' '{ print $1 }'`
      fi

    elif [ `which lsb_release 2>/dev/null` ]; then
      # get major version (e.g. '5' or '6')
      dist=`lsb_release -r | cut -f2 | awk -F '.' '{ print $1 }'`

      # get os (e.g. 'centos', 'redhatenterpriseserver', etc)
      os=`lsb_release -i | cut -f2 | awk '{ print tolower($1) }'`

    elif [ -e /etc/oracle-release ]; then
      dist=`cut -f5 --delimiter=' ' /etc/oracle-release | awk -F '.' '{ print $1 }'`
      os='ol'

    elif [ -e /etc/fedora-release ]; then
      dist=`cut -f3 --delimiter=' ' /etc/fedora-release`
      os='fedora'

    elif [ -e /etc/redhat-release ]; then
      os_hint=`cat /etc/redhat-release  | awk '{ print tolower($1) }'`
      if [ "${os_hint}" = "centos" ]; then
        dist=`cat /etc/redhat-release | awk '{ print $3 }' | awk -F '.' '{ print $1 }'`
        os='centos'
      elif [ "${os_hint}" = "scientific" ]; then
        dist=`cat /etc/redhat-release | awk '{ print $4 }' | awk -F '.' '{ print $1 }'`
        os='scientific'
      else
        dist=`cat /etc/redhat-release  | awk '{ print tolower($7) }' | cut -f1 --delimiter='.'`
        os='redhatenterpriseserver'
      fi

    else
      aws=`grep -q Amazon /etc/issue`
      if [ "$?" = "0" ]; then
        dist='6'
        os='aws'
      else
        unknown_os
      fi
    fi
  fi

  if [[ ( -z "${os}" ) || ( -z "${dist}" ) ]]; then
    unknown_os
  fi

  # remove whitespace from OS and dist name
  os="${os// /}"
  dist="${dist// /}"

  echo "Detected operating system as ${os}/${dist}."

  if [ "${dist}" = "8" ]; then
    _skip_pygpgme=1
  else
    _skip_pygpgme=0
  fi
}

install()
{
	case "$os" in
		aws|amzn)
			curl -L https://raw.githubusercontent.com/gravitee-io/scripts/master/am/4.x/amzn/install_amzn_${dist}.sh | bash
		;;
		ol|centos|rhel)
			curl -L https://raw.githubusercontent.com/gravitee-io/scripts/master/am/4.x/redhat/install_redhat.sh | bash
		;;
    sles)
      curl -L https://raw.githubusercontent.com/gravitee-io/scripts/master/am/4.x/sles/install_sles.sh | bash
    ;;
		*)  
			echo "Install script called with unknown OS \`$os'" >&2
			exit 1
		;;
	esac
}

main ()
{
	welcome
	detect_os
	install
}

main