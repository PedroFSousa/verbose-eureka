#!/bin/bash

##### FUNCTIONS #####

# Check if the available space in a given directory is >= $min_data_root_space
data_root_space_check () {
  col=$(df -P $1 | head -n1 | awk '$1=$1' | tr " " "\n" | grep -nE "(Available|available)" | cut -d':' -f 1)
  ! [ "$col" -eq "$col" ] 2>/dev/null && return 2

  space_left=$(df -P $1 | awk -v col="$col" 'NR==2 {print $col}')
  ! [ "$space_left" -eq "$space_left" ] 2>/dev/null && return 2 # not int

  [ "$space_left" -lt $min_data_root_space ] && return 1

  return 0
}

# Remove the given argumanet from the Docker daemon command
docker_daemon_rm_arg.old () {
  sed -i -r -e "s@\-\-$1=[^ ]*( |$)@@g" /usr/lib/systemd/system/docker.service
}

# Check if the given argument is set in the docker daemon command
docker_daemon_arg_exists.old () {
  exists=$(grep -E "ExecStart.*\-\-$1=.*" /usr/lib/systemd/system/docker.service)
  echo -n $exists
}

# Get the value of the given argument in the docker daemon command
docker_daemon_get_arg.old () {
  dd_arg=$(grep -oE "\-\-$1=[^ ]*( |$)" /usr/lib/systemd/system/docker.service | awk -F'=' '{print $2}')
  echo -n $dd_arg
}

# Add argument to Docker daemon command
docker_daemon_set_arg.old () {
  arg=$1
  value=$2
  quiet=$3

  arg_exists=$(docker_daemon_arg_exists $arg)
  (
    ([ ! -z "$arg_exists" ] && \
    sed -i -r -e "s@\-\-$arg=[^ ]*( |$)@\-\-$arg=$value @g" /usr/lib/systemd/system/docker.service) || \
    ([ -z "$arg_exists" ] && \
    sed -i -e "s|ExecStart=/usr/bin/dockerd|ExecStart=/usr/bin/dockerd --$arg=$value|g" /usr/lib/systemd/system/docker.service)
  ) || \
  err "Failed to add $arg argument to Docker daemon."

  if [ -z "$quiet" ]; then info "Docker daemon set to run with argument $arg=$value."; fi
}

# Get the value of an argument from $daemon_conf_path
docker_daemon_get_arg () {
  if [ $(docker_daemon_arg_exists $1) == 1 ]; then
    arg_value=$(cat $daemon_conf_path | python -c "import sys, json; print(json.load(sys.stdin)[\"$1\"])" || true)
    echo -n $arg_value
  fi

  return 0
}

# Set an argument in $daemon_conf_path
docker_daemon_set_arg () {
  arg=$1
  value=$2
  quiet=$3

  new_daemon_conf=$(cat $daemon_conf_path | python -c "import sys, json; daemon=json.load(sys.stdin); daemon[\"$arg\"]=\"$value\"; print(json.dumps(daemon, indent=2, sort_keys=True))") && \
  echo "$new_daemon_conf" > $daemon_conf_path || \
  err "Failed to add '$arg' argument to Docker daemon."

  if [ -z "$quiet" ]; then
    info "Docker daemon set to run with argument '$arg=$value'." && \
    validate_daemon_conf
  fi

  return 0
}

# Remove an argument from $daemon_conf_path
docker_daemon_rm_arg () {
  if [ $(docker_daemon_arg_exists $1) == 1 ]; then
    new_daemon_conf=$(cat $daemon_conf_path | python -c "import sys, json; daemon=json.load(sys.stdin); del daemon[\"$1\"]; print(json.dumps(daemon, indent=2, sort_keys=True))")
    echo "$new_daemon_conf" > $daemon_conf_path || \
    err "Failed to remove '$1' argument from Docker daemon."

    info "Removed argument '$1' from Docker daemon."
    validate_daemon_conf
  fi

  return 0
}

# Check if an argument is set in $daemon_conf_path
docker_daemon_arg_exists () {
  cat /etc/docker/daemon.json | python -c "import sys, json; daemon=json.load(sys.stdin); print(int(\"$1\" in daemon.keys()))"
  return 0
}

# Parse $daemon_conf_path to validate configuration 
validate_daemon_conf () {
  info "Current daemon.json:" && \
  cat $daemon_conf_path && \
  python -mjson.tool $daemon_conf_path > /dev/null || \
  err "Invalid Docker daemon configuration file: $daemon_conf_path"

  return 0
}

# Save original daemon args in $daemon_conf_path and activate rollback upon error
prepare_rollback () {
  info "Prepearing rollback..."
  userns_enabled=$(docker_daemon_arg_exists "userns-remap")
  data_root_is_custom=$(docker_daemon_arg_exists "data-root")

  [ $userns_enabled == 1 ] && \
  original_docker_userns_remap=$(docker_daemon_get_arg "userns-remap") && \
  need_rollback=1

  [ $data_root_is_custom == 1 ] && \
  original_docker_data_root=$(docker_daemon_get_arg "data-root") && \
  need_rollback=1

  return 0
}

# Check if a file is empty (ignoring newlines and whitespaces)
file_is_empty () {
  grep -q '[^[:space:]]' $1 2>/dev/null && echo -n 0 || echo -n 1
  return 0
}

# Create Docker daemon conf file if it does not exist
docker_daemon_check_conf () {
  info "Checking current Docker daemon configuration..."
  if [ ! -f $daemon_conf_path ] || [ $(file_is_empty $daemon_conf_path) == 1 ]; then
    echo "{}" > $daemon_conf_path
  else
    validate_daemon_conf
    prepare_rollback
  fi

  return 0
}


##### START SETUP #####

# Update all packages on the system
info "Updating all packages..."
yum -y update

# Enable user namesapces in the kernel
# - Change max_user_namespaces
# - Set namespace.unpriv_enable and user_namespace.enable to 1
info "Enabling user namespaces in the kernel..."

curr_max_user_namespaces=$(cat /proc/sys/user/max_user_namespaces)
kernel_args=$(grep -E 'namespace.unpriv_enable=1.*user_namespace.enable=1' /proc/cmdline || true)

if [ ! -z "$kernel_args" ] && [ "$curr_max_user_namespaces" -eq "$max_user_namespaces" ]; then
  info "User namespaces already enabled."
else
  if [ -z "$kernel_args" ]; then
    grubby --args="namespace.unpriv_enable=1 user_namespace.enable=1" --update-kernel="$(grubby --default-kernel)" && \
    info "Added namespace.unpriv_enable and user_namespace.enable as kernel arguments." || \
    err "Failed to add kernel arguments."
  fi

  if [ "$curr_max_user_namespaces" -ne "$max_user_namespaces" ]; then
    echo "user.max_user_namespaces=$max_user_namespaces" >> /etc/sysctl.conf && \
    sysctl -p || \
    err "Failed to change max_user_namespaces."

    # https://superuser.com/questions/1420967/permission-denied-when-systemd-sysctl-service-starts-and-tries-to-write-to-file
    # workaround:
    if [ "$os" = "centos" ]; then
      echo "/bin/echo $max_user_namespaces > /proc/sys/user/max_user_namespaces || /bin/echo" >> /etc/rc.d/rc.local
      chmod +x /etc/rc.d/rc.local
    fi
  fi

  info "User namespaces have been enabled."
  warn "A system reboot is required."
  echo -e "\n$(color 31 "Please run the script again after reboot!")\nPress any key to reboot$(indent 1)(Ctrl-C to cancel)\n"
  read -n 1 -s -r
  reboot
fi

if [ "$os" = "rhel" ]; then
  # Enable Red Hat repos:
  # - Extras repo (contains container-selinux package required for docker-ce)
  # - Optional and Software Collections repo (required for Python 3.6)
  info "Enabling required repos..."
  subscription-manager repos --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-optional-rpms --enable=rhel-server-rhscl-7-rpms || \
  err "Failed to enable repos."
fi

# Install yum-utils (contains yum-config-manager required to add docker-ce repo)
info "Installing yum-utils..."
yum install -y yum-utils || \
err "Failed to install yum-utils."

# Install rsync (required for copying Docker volumes)
info "Installing rsync..."
yum install -y rsync || \
err "Failed to install rsync."

# Add Docker CE repo
info "Adding Docker CE repo..."
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || \
err "Failed to add Docker CE repo."

# Install Python 3.6
info "Configuring Python 3.6..."
(
  ([ "$os" = "rhel" ] && yum install -y @development) || \
  ([ "$os" = "centos" ] && yum install -y centos-release-scl)
) && \
yum install -y rh-python36 && \
python36_path=$(scl enable rh-python36 "which python3.6") && \
pip_path=$(scl enable rh-python36 "which pip") && \
ln -nsf $python36_path /bin/python3.6 && \
ln -nsf $pip_path /bin/pip || \
err "Failed to configure Python 3.6."

# Install Docker CE and set the daemon to automatically start on boot
info "Configuring Docker CE..."
yum list installed docker-ce 2>/dev/null || yum install -y docker-ce && \
systemctl enable docker || \
err "Failed to configure Docker CE."


##### DOCKER DAEMON CONF #####

# Check Docker daemon configuration
# - Create daemon.conf if it does not exist
# - Parse daemon.json configuration (for validation)
docker_daemon_check_conf

# Configure user namespaces in the Docker daemon
# - Set user/group ID ranges for user dockremap
# - Add 'userns-remap' argument to Docker daemon
# - Start Docker daemon (this should create the dockremap user automatically)
info "Configuring user namespaces in the Docker daemon..."

arg_exists=$(docker_daemon_arg_exists "userns-remap")
[ $arg_exists == 0 ] && \
warn "Docker user namespaces are about to be enabled (https://docs.docker.com/engine/security/userns-remap).\nIf you have run a Coral Docker stack before, be aware that after this script is done, the stack will have to be restarted and you will have to provide the same passwords as before." && \
echof "Press any key to proceed\t(Ctrl-C to cancel)\n" && \
read -n 1 -s -r

dockremap_entry=dockremap:$dockremap_id_first:$dockremap_id_range
(grep $dockremap_entry /etc/subuid || echo $dockremap_entry >> /etc/subuid) && \
(grep $dockremap_entry /etc/subgid || echo $dockremap_entry >> /etc/subgid) && \
info "User/group ID ranges for user dockremap are set." || \
err "Failed to set user/group ID ranges for user dockremap."

docker_daemon_set_arg "userns-remap" "default"

# Configure Docker data root (default is /var/lib/docker)
# - Prompt for a directory and check if it has at least 100GB available
# - If different from current data root, set the 'data-root' argument in
# daemon.json and move current volumes (if any) to the new data root 
info "Configuring the Docker data root..."

default_data_root_info=
data_root_to_use=

# determine current data root
current_data_root=$(docker_daemon_get_arg "data-root")
if [ -z "$current_data_root" ]; then
  current_data_root=$default_data_root
  default_data_root_info="(default)"
fi

# prompt for new data root
docker_data_root_info="\nThe Docker $(bold "$(uline "data root")") is the directory where persisted data such as images, volumes, and cluster state are stored.
All the data from a Coral stack will be stored in the Docker data root directory.\n
Current data root: $(bold "$(uline "$current_data_root")") $default_data_root_info"

echof "$docker_data_root_info" 1
while true;
do
  read -p "$(echof "Would you like to specify a different data root? (y/n) " 1)" -r res
  [[ $res =~ ^([yY]|[nN])$ ]] && break
done

if [[ $res =~ ^[yY]$ ]]; then
  warn "If you have run a Coral Docker stack before, be aware that after changing the data root, the stack may have to be restarted and you will have to provide the same passwords as before.\n" 1  
  while true;
  do
    read -p "$(echof "New data root directory: " 1)" -r -e new_data_root
    [ -z "$new_data_root" ] && continue
    [ ! -d "$new_data_root" ] && warn "Directory '$new_data_root' does not exist." 1 && continue
    echo && break
  done
else
  echo
  info "Docker will use the current data root: $current_data_root."
fi

if [ ! -z "$new_data_root" ]; then
  data_root_to_use=$new_data_root
else
  data_root_to_use=$current_data_root
fi

if [ ! -d "$data_root_to_use" ]; then
  mkdir -p $data_root_to_use || \
  err "Failed to create directory $data_root_to_use."
fi

# check available space in data_root_to_use
check=0
data_root_space_check $data_root_to_use || \
{
  check=$(echo $?)
  force_info="If you are sure you want to use this data root, run the script with the '-f' argument."
  check_err1_msg="Space available in '$data_root_to_use' is less than the recommended minimum of 100GB."
  check_err2_msg="Could not determine available sapce in '$data_root_to_use'."

  if [ "$force" -eq 1 ]; then
    ([ "$check" -eq 1 ] && warn "$check_err1_msg") || \
    ([ "$check" -eq 2 ] && warn "$check_err2_msg")

    ([ "$check" -eq 1 ] || [ "$check" -eq 2 ]) && \
    warn "Forcing$([ "$check" -eq 2 ] && echo " possibly" ) undersized data root: $data_root_to_use."
  else
    ([ "$check" -eq 1 ] && err "$check_err1_msg $force_info") || \
    ([ "$check" -eq 2 ] && err "$check_err2_msg $force_info")
  fi
}

[ "$check" -eq 0 ] && info "Directory '$data_root_to_use' has the recommended minimum (100GB) of available space."

# set the 'data-root' argument in daemon.json
if [ "$data_root_to_use" = "$default_data_root" ]; then
  docker_daemon_rm_arg "data-root"
else
  docker_daemon_set_arg "data-root" "$data_root_to_use"
fi

# move volumes if data root was changed
dockremap_current_root_dir=$current_data_root/$dockremap_id_first.$dockremap_id_first
[ ! -d "$dockremap_current_root_dir" ] && first_time_ns=1
[ "$data_root_to_use" != "$current_data_root" ] && data_root_changed=1

if [ "$data_root_changed" = 1 ] || [ "$first_time_ns" = 1 ]; then
  # determine current volumes directory
  if [ "$first_time_ns" = 1 ]; then
    current_volumes_dir=$current_data_root/volumes
  else
    current_volumes_dir=$dockremap_current_root_dir/volumes
  fi

  if [ ! -d "$current_volumes_dir" ] || [ "$(ls "$current_volumes_dir")" = "metadata.db" ]; then
    info "No Docker volumes were found in the current data root ($current_data_root)."
  else
    info "Docker volumes were found in the current data root ($current_data_root).\n"
    while true;
    do
      read -p "$(echof "Would you like to copy these volumes to the new data root? (y/n) " 1)" -r res
      [[ $res =~ ^([yY]|[nN])$ ]] && echo && break
    done

    if [[ $res =~ ^[yY]$ ]]; then
      info "Copying Docker volumes from $current_data_root to $data_root_to_use..."

      # prepare new data root
      dockremap_new_root_dir=$data_root_to_use/$dockremap_id_first.$dockremap_id_first
      if [ -d $dockremap_new_root_dir ]; then
        info "Also found existing volumes in new data root. Backing them up..." && \
        backup_dir=${dockremap_new_root_dir}_$(date +"%Y%m%d-%H%M%S.%N") && \
        mv $dockremap_new_root_dir $backup_dir && \
        info "Existing volumes in new data root were backed up into: $backup_dir." || \
        err "Failed to back up existing volumes in new data root."
      fi

      mkdir -p $dockremap_new_root_dir && \
      chown -R $dockremap_id_first:$dockremap_id_first $dockremap_new_root_dir

      # copy volumes
      rsync -avhAXog --devices --specials $current_volumes_dir $dockremap_new_root_dir || \
      err "Failed to copy volumes to new data root."

      # if 1st time ns, let dockremap take ownership of the volumes
      [ "$first_time_ns" = 1 ] && find $dockremap_new_root_dir ! -path $dockremap_new_root_dir -type d | xargs chown -R $dockremap_id_first:$dockremap_id_first
    fi
  fi
fi

info "Starting the Docker daemon..."
systemctl daemon-reload && \
systemctl restart docker || \
err "Failed to start the Docker daemon."

# Check if Docker created the dockremap user
id dockremap || \
err "User dockremap has not been created by Docker."
info "Docker is correctly configured to map the root user inside containers to the dockremap user on the host."

# Install docker-compose
info "Installing Docker Compose..."
$(which pip) install --upgrade pip && \
$(which pip) install docker-compose && \
compose_path=$(scl enable rh-python36 "which docker-compose") && \
ln -nsf $compose_path /bin/docker-compose && \
info "Docker Compose is installed." || \
err "Failed to install Docker Compose."
