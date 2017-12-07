#!/bin/bash

##############################
# Vars, checks and admin
##############################

source /dcos/bin/envs.sh

# Workaround to pass add_auth on the one liner as zk-shell doens't provide this as a param

function run_command {
  echo -e "zk-shell --run-from-stdin master.mesos:2181 << EOF\nadd_auth digest $OVPN_USERNAME:$OVPN_PASSWORD\n$1\nEOF" | sh
  return $?
}

function fix_scripts {
  # Fix a bug in zk-shell copy that's pending a pull request
  sed -i 's/return PathValue("".os.path.join(fph.readlines()))/return PathValue("".join(os.path.join(fph.readlines())))/g' /usr/lib/python2.7/site-packages/zk_shell-1.1.3-py2.7.egg/zk_shell/copy.py
  
  # Replace the shipped easyrsa with our easyrsa to remove the revoke confirmation
  sed -i 's/easyrsa/\/dcos\/bin\/easyrsa/g' /usr/local/bin/ovpn_revokeclient
}

##############################
# File download and upload
##############################

function download_files {
  if [[ $(run_command "find /openvpn/ upload_marker") = "" ]]; then
    ZKPATH_STRIPPED=$(echo $ZKPATH | sed -e 's/^\///')
    for fname in $(run_command "find / $ZKPATH_STRIPPED"); do
      local sub_path=$(echo $fname | cut -d/ -f3-)

      # If the sub_path is empty, there's no reason to copy
      [[ -z $sub_path ]] && continue

      if [ "$sub_path" == "Failed" ]; then
        err "Unable to get data from $ZKURL$ZKPATH. Check your zookeeper."
      fi
    
      local fs_path=$CONFIG_LOCATION/$sub_path
      run_command "cp $fname file://$fs_path false true false false" > /dev/null 2>&1
      # Directories are copied as empty files, remove them so that the
      # subsequent copies actually work.
      [ -s $fs_path ] || rm $fs_path
    done
  else
    echo "INFO: Upload marker found, leaving until next cron run"
  fi
}

function upload_files {

  # Adding a marker so we know when all the files have been uploaded 
  run_command "create $ZKPATH/upload_marker ''"

  for fname in $(find $CONFIG_LOCATION -not -type d); do
    local zk_location=$(echo $fname | sed 's|'$CONFIG_LOCATION'/|/|')
    run_command "cp file://$fname $ZKPATH$zk_location false true false true" > /dev/null 2>&1
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
  run_command "cp $index_on_zk file://$index_tmp false true false true" > /dev/null 2>&1
  if [[ $(diff -q $index_on_local $index_tmp) != "" ]]; then
    if [[ $(run_command "find /openvpn/ upload_marker") = "" ]]; then
      echo "INFO: Zookeeper has a new dataset, downloading and restarting OpenVPN to apply"
      download_files
      pkill openvpn
      ovpn_run --daemon
      set_public_location
    else
      echo "INFO: Upload marker found, will attempt on next cron run"
    fi
  else
    echo "INFO: No changes found on Zookeeper"
  fi
}


##############################
# Location set and get
##############################

function get_location {
  cat /etc/openvpn/location.conf
}

function set_public_location {
  source $OPENVPN/ovpn_env.sh
  echo "INFO: Setting public location"
  echo "remote $(wget -q -O - -U curl ipinfo.io/ip) $PORT1 $OVPN_PROTO" > /etc/openvpn/location.conf
}


##############################
# Main setup
##############################

function create_zkpath {
  if [[ $(run_command "find /openvpn") = "" ]]; then
    echo "INFO: Creating the zkpath if it doesn't already exist"
    run_command "create $ZKPATH '' false false true"
    run_command "set_acls /$ZKPATH username_password:$OVPN_USERNAME:$OVPN_PASSWORD:cdrwa"
  fi
}

function build_configuration {
  # Adding a lock to stop any other instances trying to upload at the same time
  echo "INFO: Creating lock file"
  run_command "create $ZKPATH/upload_marker ''" > /dev/null 2>&1
  echo "INFO: Resetting container"
  reset_container
  echo "INFO: Building configuration"
  ovpn_genconfig -u udp://$CA_CN > /dev/null 2>&1
  echo "INFO: Building PKI"
  (echo $CA_CN) | PATH=/dcos/bin:$PATH ovpn_initpki nopass
  touch /etc/openvpn/complete
}

function setup {
  # Introduce a random delay between 1-21 seconds in case of multiple instances starting at the same time
  sleep $[ ( $RANDOM % 20 )  + 1 ]s

  create_zkpath

  if [[ $(run_command "find /openvpn/ complete") = "" ]]; then
    echo "INFO: I didn't find a marker signifying a full dataset on Zookeeper"
    if [[ $(run_command "find /openvpn/ upload_marker") = "" ]]; then
      echo "INFO: I didn't find a lock"
      build_configuration
      echo "INFO: Uploading files to Zookeeper"
      upload_files
      set_public_location
    else
      echo "INFO: Lock found, will random sleep then try again"
      setup
    fi
  else
    if [[ $(run_command "find /openvpn/ upload_marker") = "" ]]; then
      reset_container
      echo "INFO: Files found in Zookeeper, no lock found, downloading to container"
      download_files
      set_public_location
    else
      echo "INFO: Lock found, will random sleep then try again"
      setup
    fi
  fi
}

function run_server {
  source /dcos/bin/envs.sh
  fix_scripts
  setup
  echo "INFO: Starting crond"
  crond
  echo "INFO: Adding cron job for synchronisation"
  echo "*/2 * * * * /dcos/bin/run.sh synchronise >> /mnt/mesos/sandbox/stdout 2>&1" >> /etc/crontabs/root
  echo "INFO: Starting OpenVPN daemon"
  ovpn_run --daemon
  echo "INFO: Starting Python REST interface"
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
  build_configuration) build_configuration ;;
  set_public_location) set_public_location ;;
  get_location)        get_location ;;
  reset)               reset ;;
  reset_container)     reset_container ;;
  synchronise)         synchronise ;;
  *) exit 1 ;;
esac
