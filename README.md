DC/OS OpenVPN
===============

OpenVPN server and REST management interface package for DC/OS

Please note: This is a DC/OS Community package, which is not supported by Mesosphere Customer support.

All issues and PRs should be raised on this repository.

Features
--------------

1. Inherits OpenVPN in Docker from https://hub.docker.com/r/kylemanna/openvpn
1. Automatically configures PKI, certificates and runs OpenVPN without user interaction
1. Provides a REST interface for adding, revoking users and accessing their credentials for use with a suitable client
1. Exposes endpoints for OpenVPN - 1194/TCP & UDP, 5000/TCP REST
1. The REST interface uses Flask-BasicAuth and defined environment variables ovpn_username & ovpn_password which must be defined before installation
1. TLS is enabled by default on the REST interface - currently using the self signed openvpn certificate
1. The Zookeeper znode dcos-vpn has ACLs enabled using the secrets and protects server and client credentials
1. Synchronisation of assets between the container and Zookeeper in case the container is restarted
1. Clients revoked through the REST interface are correctly revoked from OpenVPN
1. Merged the previously separate openvpn server & openvpn-admin packages into one. The openvpn-admin package is no longer required.

DC/OS Public Universe Installation
--------------

1. From the **DC/OS Dashboard > Universe > Packages > enter openvpn in the search box**
1. Select Install Package > Advanced Installation and scroll down
1. Configure both the ovpn_username & ovpn_password, which are required for the REST interface auth and for the Zookeeper ACL credentials
1. Select Review and Install > Install
1. The service is installed and runs through its configuration. When complete, it'll be marked as Running and Healthy
1. See Troubleshooting for any issues, otherwise go to Usage

Marathon Installation
--------------

1. Clone this repository locally and amend marathon.json to configure the ovpn_username & ovpn_password environment variables
1. Add the task to Marathon using the DC/OS CLI `dcos marathon app add marathon.json`
1. The service is installed and runs through its configuration. When complete, it'll be marked as Running and Healthy
1. See Troubleshooting for any issues, otherwise go to Usage

Local Universe Installation For Development
--------------

The task can be also be added as a package to a local Universe repository

1. Clone https://github.com/mesosphere/universe
1. Read https://docs.mesosphere.com/1.9/administering-clusters/deploying-a-local-dcos-universe/
1. Use the supplied simple helper script called local_universe_setup.sh to facilitate building and publishing

Usage
--------------

### Endpoints

The exact endpoints can be confirmed from **DC/OS Dashboard > Services > OpenVPN > <running task> > Details**

1. OpenVPN is presented on 1194/UDP and any OpenVPN client will default to this port
1. The REST management interface is available on 5000/TCP and will be accessed at https://<IP>:5000
1. /status /test /client are all valid REST endpoints. /status does not require authentication as it is used for health checks


### Add a User

1. Authenticate and POST to the REST endpoint, the new user's credentials will be output to the POST body
```
curl -k -u username:password -X POST -d "name=richard" https://<IP>:5000/client
```
2. Copy the entire ouput and save to a single file called dcos.ovpn and add to a suitable OpenVPN client
3. You may need to review and amend the target server IP in the credentials
4. Test connecting with the OpenVPN client. For troubleshooting, OpenVPN clients offer useful output for debugging
5. The new client credentials will be backed up to Zookeeper for persistence in case the task is killed, and will be copied back as required

### Revoke a User

1. Using the same client endpoint, append the name of the user you wish to revoke
```
curl -k -u username:password -X DELETE https://<IP>:5000/client/richard
```
2. The client is correctly revoked from OpenVPN and the assets are removed from the container and Zookeeper

### Remove persistent data

Recursively delete the dcos-vpn znode, authenticating using the same ovpn_username and ovpn_password credentials configured on install

zk-shell and zkCLI can both be used.  TODO: Examples.


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

1. Review stdout and stderr from the task's logs under the DC/OS Dashboard > Service > openvpn > running task > logs
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
1. Get defined host ports working in the marathon.json - works in the Universe marathon template
1. The patch for zk-shell https://github.com/rgs1/zk_shell/pull/82 as managed in run.bash around line 100 needs removing when zk-shell is fixed
1. Examples for removing the znode
1. Update the /status endpoint for ovpn_status output and tie into a healthcheck
1. run.sh usage and tidying
1. Update for DC/OS 1.10 and file based secrets
1. Either extend zk-shell to add auth to its params or replace with Kazoo code
1. Replace the location function which calls out to ifconfig.me as it's of no use for internal networks
