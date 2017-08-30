DC/OS OpenVPN
===============

OpenVPN server and REST management interface package for DC/OS

Please note: This is a [DC/OS Community package](https://dcos.io/community/), which is not supported by Mesosphere Customer support.

All issues and PRs should be raised on this repository.

Features
--------------

1. Inherits OpenVPN in Docker from https://hub.docker.com/r/kylemanna/openvpn
1. Automatically configures PKI, certificates and runs OpenVPN without user interaction
1. Provides a REST interface for adding, revoking users and accessing their credentials for use with a suitable client
1. Exposes endpoints for OpenVPN - 1194/TCP & UDP, 5000/TCP REST
1. The REST interface uses Flask-BasicAuth and DC/OS secrets for basic (username & password) authentication
1. TLS is enabled by default on the REST interface - currently using the self signed openvpn certificate
1. The Zookeeper znode dcos-vpn has ACLs enabled using the secrets and protects server and client credentials
1. Synchronisation of assets between the container and Zookeeper in case the container is restarted
1. Clients revoked through the REST interface are correctly revoked from OpenVPN
1. Merged the previously separate openvpn server & openvpn-admin packages into one. The openvpn-admin package is no longer required.

Task Installation
--------------

The simplest method of installation is simply to add it as a new Marathon task:

1. You must add the secrets to DC/OS; ovpn_username & ovpn_password. Without these, the task will not launch
1. Clone this repo to your machine
1. Using the DC/OS cli add the task `dcos marathon app add config.json`
1. From the DC/OS UI > Services > openvpn
1. Check it's running, if failed, goto the most recent failed task > Logs > Stderr
1. From Services > openvpn > latest running task > Details
1. The first endpoint address is the REST interface, the second is the OpenVPN endpoint
1. Launch the first endpoint address and append /test to the end of the URL
1. Authenticate using the username and password added to secrets, now move onto managing users

Local Universe Installation
--------------

The task can be also be added as a package to a local Universe repository

https://github.com/mesosphere/universe
https://docs.mesosphere.com/1.9/administering-clusters/deploying-a-local-dcos-universe/

A simple helper script called local_universe_setup.sh is available for testing

This requires a Docker registry to be available to publish the image to and for DC/OS to be able to access it.

Managing Users
--------------

### Add User
1. Authenticate and POST to the REST endpoint (found under the UI > services > openvpn > task > details). The new user's credentials will be output to the POST body. Add these to a suitable OpenVPN client and note to amend the target IP to that of the OpenVPN endpoint.
1. The new assets will be copied to Zookeeper for persistence in case the task is killed, and will be copied back to the container on startup.
```
curl -k -u admin:password -X POST -d "name=richard" https://<REST endpoint ip:port>/client
```

### Revoke User
1. Calls easyrsa revokeclient to correctly revoke the client, removes all assets locally and from Zookeeper
```
curl -k -u admin:password -X DELETE https://<REST endpoint ip:port>/client/richard
```

How it works
--------------

Inherits the OpenVPN image from https://hub.docker.com/r/kylemanna/openvpn with a shell script to auto-configure OpenVPN without prompts, execute
the OpenVPN daemon and launch the REST interface.

bin/run.sh, dcos_openvpn/web.py & dcos_openvpn/cert.py provide the main functionality.

Python Flask provides the web microframework.

zk-shell https://github.com/rgs1/zk_shell is used to interact with Zookeeper. In order to enable ACLs and use it programmatically, required creative
use of their stdin option. This is wrapped in the run_command function in run.sh.

zkshrun.sh is a little standalone helper script that provides run_command to the cert.py.

A modified version of easyrsa is shipped which removes user prompts.

### Startup order
1. run.sh checks for existing assets in Zookeeper and copies them to the container if they exist, otherwise initpki and genconfig are run
1. Launchs the OpenVPN daemon in daemon mode, passing --daemon
1. Starts the Python REST interface


Troubleshooting
--------------

1. Review stdout and stderr from the task's logs under the DC/OS UI > Service > openvpn > running task > logs
2. If the task is running on DC/OS, get a shell on the running container to investigate further:
```
docker ps
docker exec -it <Container ID> /bin/bash
```
/dcos/bin/runs.sh & /dcos/dcos_openvpn/web.py are the two main files to investigate.

The container can also be launched local onto a Docker daemon.

`run.sh reset` & `run.sh reset_container` are useful for testing, resetting both the Zookeeper znode & container and just the container respectively.

Modifying run.sh run_server as follows it useful for testing changes to the REST interface

```
function run_server {
  source /dcos/bin/envs.sh
  check_status
  setup
  #ovpn_run --daemon
  ovpn_run
  #/usr/bin/python -m dcos_openvpn.main
}
```

Todo
--------------
1. The patch for zk-shell https://github.com/rgs1/zk_shell/pull/82 as managed in run.bash around line 100 needs removing when zk-shell is fixed
1. Update the /status endpoint for ovpn_status output and tie into a healthcheck
1. run.sh usage and tidying
1. Update for DC/OS 1.10 and file based secrets
1. Either extend zk-shell to add auth to its params or replace with Kazoo code
