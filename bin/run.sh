#!/bin/bash

##############################
# Vars, checks and admin
##############################

container_files=0
zookeeper_path=0
source /dcos/bin/envs.sh

# Check to see if the container already has the openvpn files locally
# And the second checks for an existing znode in Zookeeper which suggests
# This is being re-run after a previous setup

function check_status {
  if [ -f $CONFIG_LOCATION/openvpn.conf ]; then
    container_files=1
  fi
  if [[ -z $(run_command "ls $ZKPATH/openvpn.conf") ]]; then
    zookeeper_path=1
  fi
  echo "container_files = " $container_files
  echo "zookeeper_path  = " $zookeeper_path
}

# Workaround to pass add_auth on the one liner as zk-shell doens't provide this as a param

function run_command {
  echo -e "zk-shell --run-from-stdin master.mesos:2181 << EOF\nadd_auth digest $OVPN_USERNAME:$OVPN_PASSWORD\n$1\nEOF" | sh
  return $?
}

##############################
# File download and upload
##############################

function download_files {
  if [[ $(run_command "ifind /openvpn/upload_marker") = "" ]]; then
    ZKPATH_STRIPPED=$(echo $ZKPATH | sed -e 's/^\///')
    for fname in $(run_command "find / $ZKPATH_STRIPPED"); do
      local sub_path=$(echo $fname | cut -d/ -f3-)

      # If the sub_path is empty, there's no reason to copy
      [[ -z $sub_path ]] && continue

      if [ "$sub_path" == "Failed" ]; then
        err "Unable to get data from $ZKURL$ZKPATH. Check your zookeeper."
      fi
    
      local fs_path=$CONFIG_LOCATION/$sub_path
      run_command "cp $fname file://$fs_path false true false true"
      # Directories are copied as empty files, remove them so that the
      # subsequent copies actually work.
      [ -s $fs_path ] || rm $fs_path
    done
  else
    echo "Upload marker found, leaving until next cron run"
  fi
}

function upload_files {
  if [ $zookeeper_path = 0 ]; then
  	run_command "create $ZKPATH '' false false true"
  	run_command "set_acls /$ZKPATH username_password:$OVPN_USERNAME:$OVPN_PASSWORD:cdrwa"
  fi

  # Adding a marker so we know when all the files have been uploaded 
  run_command "create $ZKPATH/upload_marker ''"

  for fname in $(find $CONFIG_LOCATION -not -type d); do
    local zk_location=$(echo $fname | sed 's|'$CONFIG_LOCATION'/|/|')
    run_command "cp file://$fname $ZKPATH$zk_location false true false true"
  done

  # Removing upload marker 
  run_command "rm $ZKPATH/upload_marker"
}


##############################
# Synchronise
##############################

function synchronise {
  index_on_zk="/openvpn/pki/index.txt"
  index_on_local="/etc/openvpn/pki/index.txt"
  index_tmp="/tmp/index.txt"

  rm -f $index_tmp
  run_command "cp $index_on_zk file://$index_tmp false true false true"
  if [[ $(diff -q $index_on_local $index_tmp) != "" ]]; then
    if [[ $(run_command "ifind /openvpn/upload_marker") = "" ]]; then
      download_files
      pkill openvpn
      ovpn_run --daemon
      set_public_location
    else
      echo "Upload marker found will attempt on next cron run"
    fi
  else
    echo "index.txt matches so nothing to do"
  fi
}


##############################
# Location set and get
##############################

function get_location {
  cat /etc/openvpn/location.conf
}

function set_public_location {
  echo "remote $(wget -q -O - -U curl ipinfo.io/ip) $PORT1 $OVPN_PROTO" > /etc/openvpn/location.conf
}


##############################
# Main setup
##############################

function build_configuration {
  ovpn_genconfig -u udp://$CA_CN
  rm -rf $CONFIG_LOCATION/pki
  (echo $CA_CN) | PATH=/dcos/bin:$PATH ovpn_initpki nopass
}

function setup {

  # Fix a bug in zk-shell copy that's pending a pull request
  sed -i 's/return PathValue("".os.path.join(fph.readlines()))/return PathValue("".join(os.path.join(fph.readlines())))/g' /usr/lib/python2.7/site-packages/zk_shell-1.1.3-py2.7.egg/zk_shell/copy.py
  
  # Replace the shipped easyrsa with our easyrsa to remove the revoke confirmation
  sed -i 's/easyrsa/\/dcos\/bin\/easyrsa/g' /usr/local/bin/ovpn_revokeclient

  if [ $zookeeper_path = 1 ] && [ $container_files = 0 ]; then
    echo "Files found in Zookeeper - copying to container"
    reset_container
    download_files
  else
    echo "Files not found in Zookeeper - generating and uploading"
    reset
    build_configuration
    upload_files
  fi 
    set_public_location
}

function run_server {
  source /dcos/bin/envs.sh
  check_status
  setup
  crond
  echo "*/2 * * * * /dcos/bin/run.sh synchronise" >> /etc/crontabs/root
  ovpn_run --daemon
  /usr/bin/python -m dcos_openvpn.main
}

function reset {
  run_command "rmr $ZKPATH/" > /dev/null 2>&1
  reset_container
}

function reset_container {
  rm -rf $CONFIG_LOCATION/pki
  rm -f $CONFIG_LOCATION/openvpn.conf $CONFIG_LOCATION/crl.pem $CONFIG_LOCATION/ovpn_env.sh $CONFIG_LOCATION/location.conf
}

case "$@" in
  run_server)          run_server ;;
  setup)               setup  ;;
  download_files)      download_files ;;
  upload_files)        upload_files ;;
  check_status)        check_status ;;
  build_configuration) build_configuration ;;
  set_public_location) set_public_location ;;
  get_location)        get_location ;;
  reset)               reset ;;
  reset_container)     reset_container ;;
  synchronise)         synchronise ;;
  *) exit 1 ;;
esac
