#!/bin/bash

set -e

rollback_dockerd_args () {
  if [ ! -z "$need_rollback" ]; then
    [ -z "$original_docker_userns_remap" ] && \
    docker_daemon_rm_arg "userns-remap" || \
    docker_daemon_set_arg "userns-remap" "$original_docker_userns_remap" 1

    [ -z "$original_docker_data_root" ] && \
    docker_daemon_rm_arg "data-root" || \
    docker_daemon_set_arg "data-root" "$original_docker_data_root" 1

    echo "Rolled back Docker daemon configuration."
  else
    echo "No Docker daemon configuration rollback necessary."
  fi
}
trap rollback_dockerd_args ERR

daemon_conf_path=/etc/docker/daemon.json
default_data_root=/var/lib/docker
min_data_root_space=100000000
dockremap_id_first=500000
dockremap_id_range=65536
max_user_namespaces=15000

force=0

# formatting
tab_size=4
fold_width=$(echo $(($(stty size | awk '{print $2}' 2>/dev/null) - $tab_size)) || echo 75)
tabs $tab_size
color () { echo -en "\033[1;$1m$2\033[0m"; }
bold () { echo -en "\033[1m$1\033[0m"; }
uline () { echo -en "\033[4m$1\033[0m"; }
title () { echo -en "$(bold "$(uline "$1"):\n")"; }
indent () { printf "%$1s" | tr ' ' '\t'; }
echof () { echo -e "$1" | fold -s -w $fold_width | sed -e "s|^|$(indent $2)|g";}

# log functions
err () { echof "[$(color 31 "_ERR")] $1" $2; return 1; }
info () { echof "[$(color 34 "INFO")] $1" $2; }
warn () { echof "[$(color 33 "WARN")] $1" $2; }

# parse arguments
for i in "$@"
do
  case $i in
  -f)
    force=1
    ;;
  *)
    err "Unrecognized argument: $i"
    ;;
  esac
done

# check privileges
[ "$EUID" -ne 0 ] && err "Script must be run with root privileges."

# get os
eval $(grep "^ID=" /etc/os-release || true)
os=$(echo -n $ID)
echof "Detected Linux distro: $os"

[ "$os" != "rhel" ] && [ "$os" != "centos" ] && [ "$os" != "ubuntu" ] && [ "$os" != "debian" ] && err "Unsupported Linux distro: '$os'"

# intro text
info_text="This script will configure this machine to allow for the Coral Docker stack to be deployed.
If you have any questions, please contact us at coral@lists.inesctec.pt."
todos_rhel="- Update all packages on the system (yum update)
\n- Enable repos:\n\t$(color 33 rhel-7-server-extras-rpms)\n\t$(color 33 rhel-7-server-optional-rpms)\n\t$(color 33 rhel-server-rhscl-7-rpms)
\n- Add the Docker CE repo:\n\t$(color 33 https://download.docker.com/linux/centos/docker-ce.repo)
\n- Configure user namespaces in the Linux kernel\n   (required for secure isolation of Docker containers)
\n- Install packages (and dependencies):\n\t$(color 33 yum-utils)\n\t$(color 33 rsync)\n\t$(color 33 @development)\n\t$(color 33 rh-python36)\n\t$(color 33 docker-ce)\n\t$(color 33 docker-compose)
\n- Start the Docker daemon and set it to automatically start on boot\n"
todos_centos="- Update all packages on the system (yum update)
\n- Add the Docker CE repo:\n\t$(color 33 https://download.docker.com/linux/centos/docker-ce.repo)
\n- Configure user namespaces in the Linux kernel\n   (required for secure isolation of Docker containers)
\n- Install packages (and dependencies):\n\t$(color 33 yum-utils)\n\t$(color 33 rsync)\n\t$(color 33 centos-release-scl)\n\t$(color 33 rh-python36)\n\t$(color 33 docker-ce)\n\t$(color 33 docker-compose)
\n- Start the Docker daemon and set it to automatically start on boot\n"
todos_ubuntu="- Update all packages on the system (apt-get update)
\n- Add the Docker CE repo:\n\t$(color 33 https://download.docker.com/linux/$os stable)
\n- Install packages (and dependencies):\n\t$(color 33 curl)\n\t$(color 33 apt-transport-https)\n\t$(color 33 ca-certificates)\n\t$(color 33 software-properties-common)\n\t$(color 33 gnupg)\n\t$(color 33 python3.6)\n\t$(color 33 docker-ce)\n\t$(color 33 docker-compose)
\n- Add the current user to the docker group and set ownership and permissions on the default volumes directory\n"
todos_debian=$todos_ubuntu

todos=$(echo \$todos_$os)

title "\nINTRO"
echof "$info_text\n" 1
title "YOU ARE ABOUT TO"
echof "$(eval echo $(echo $todos))" 1
echo -e "$(color 32 "Press any key to proceed")\t(Ctrl-C to cancel)\n"
read -n 1 -s -r

# execute setup script for detected os
if [ "$os" = "rhel" ] || [ "$os" = "centos" ]; then source rpm.sh
elif [ "$os" = "ubuntu" ] || [ "$os" = "debian" ]; then source deb.sh
else err "Unsupported Linux distro: '$os'"; fi

# done
info "Host is now ready to deploy the Coral Docker stack.\n"
