DC/OS OpenVPN
===============


Please note: This is a [DC/OS Community package](https://dcos.io/community/), which is not formally tested or supported by Mesosphere.

OpenVPN server and REST management interface package for DC/OS.

Please note: This is a [DC/OS Community package](https://dcos.io/community/), which is not formally tested or supported by Mesosphere.

Issues and PRs are welcome.

Please review the Changelog for recent changes


Features
--------------

1. Inherits OpenVPN in Docker from https://hub.docker.com/r/kylemanna/openvpn
1. Automatically configures PKI, certificates and runs OpenVPN without user interaction
1. Provides a REST interface for adding, revoking users and accessing their credentials for use with a suitable client
1. Exposes endpoints for OpenVPN - 1194/UDP, REST interface - 5000/TCP
1. The REST interface uses Flask-BasicAuth and defined environment variables ovpn_username & ovpn_password which must be defined before installation
1. TLS is enabled by default on the REST interface - currently using the self signed OpenVPN certificate
1. The Zookeeper znode `/openvpn` has ACLs enabled, to protect the OpenVPN server and client credentials
1. Synchronisation of assets between the container and Zookeeper in case the container is restarted
1. Clients revoked through the REST interface are correctly revoked from OpenVPN
1. Merged the previously separate openvpn server & openvpn-admin 0.0.0-0.1 packages into one. The openvpn-admin package is no longer required


Installation
--------------

**You must configure the OVPN_USERNAME & OVPN_PASSWORD environment variables before installation** These are required for both the REST interface
credentials and for the Zookeeper znode ACL. Please note, DC/OS 1.10 enforces CPU usage, key generation requires a full 1.0 CPU. This can be reduced back to 0.1 once up and running.

### DC/OS Public Universe Installation

1. From the `DC/OS Dashboard > Universe > Packages > enter openvpn in the search box`
1. Select `Install Package > Advanced Installation` and scroll down
1. Configure both the `OVPN_USERNAME` & `OVPN_PASSWORD`
1. Select `Review and Install > Install`
1. The service is installed and initialises, when complete, it'll be marked as Running and Healthy
1. See Troubleshooting for any issues, otherwise go to Usage

### Marathon Installation

1. Clone this repository locally and amend marathon.json to configure the ovpn_username & ovpn_password environment variables
1. Add the task to Marathon using the DC/OS CLI `dcos marathon app add marathon.json`

### Local Universe Installation For Development

The task can be also be added as a package to a local Universe repository

1. Clone https://github.com/mesosphere/universe
1. Read https://docs.mesosphere.com/1.9/administering-clusters/deploying-a-local-dcos-universe/


Usage
--------------

### Endpoints

The exact endpoints can be confirmed from `DC/OS Dashboard > Services > OpenVPN > <running task> > Details`

1. OpenVPN is presented on `1194/UDP` and any OpenVPN client will default to this port
1. The REST management interface is available on `5000/TCP` and will be accessed at `https://<IP>:5000`
1. /status /test /client are all valid REST endpoints. /status does not require authentication as it is used for health checks

### Add a User

1. Authenticate and POST to the REST endpoint, the new user's credentials will be output to the POST body
```
curl -k -u username:password -X POST -d "name=richard" https://<IP>:5000/client > richard.ovpn
```
2. Import the .ovpn file into any suitable OpenVPN client, Tunnelblick for macOS, for example
3. Test connecting with the OpenVPN client. See Troubleshooting for help
4. The new client credentials will be backed up to Zookeeper for persistence in case the task is killed, and will be synchronised with any other instances

### Revoke a User

1. Using the same client endpoint, append the name of the user you wish to revoke
```
curl -k -u username:password -X DELETE https://<IP>:5000/client/richard
```
2. The client is correctly revoked from OpenVPN and the change is synchronised with all running instances

### Remove Zookeeper data

During installation, an ACL is set on the Zookeeper OpenVPN znode, restricting access based on the `OVPN_USERNAME` & `OVPN_PASSWWORD` credentials.
In order to remove the znode data you must either authenticate with those same credentials or as the Zookeeper super user.

Some examples of how to achieve this using zk-shell which is shipped in the Docker image:
```
zk-shell connect master.mesos:2181
(CONNECTED) / add_auth digest <username>:<password>
(CONNECTED) / rmr /openvpn/
(CONNECTED) / exit
```

If you intend to change the `OVPN_USERNAME` & `OVPN_PASSWORD`, you will need to change the ACL on the existing znode, then reinstall the package
with new credentials
```
zk-shell connect master.mesos:2181
(CONNECTED) / add_auth digest <username>:<password>
(CONNECTED) / set_acl /openvpn world:anyone:cdrwa
(CONNECTED) / exit
```

If you wish to remove the znode entirely, you will need to authenticate with the Zookeeper super user credentials
```
zk-shell connect master.mesos:2181
(CONNECTED) / add_auth digest <super>:<password>
(CONNECTED) / rmr /openvpn
(CONNECTED) / exit
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

Synchronisation between multiple running instances is handled via a cron job, which runs every 2 minutes. It checks to see
if the `openvpn/pki/issue.txt` differs between localhost and in Zookeeper.  If there's a diff, it signifies that a user has been created
or revoked by another instance which has been uploaded to Zookeeper. The full pki directory is copied down to update the local instance
and the ovpn daemon is restarted.

This functionality is rudimentary and it's recommended not to add or revoke more than one user at a time and then leave >3 minutes between
each change to allow the synchronisation to work.

### Startup order
1. run.sh checks for existing assets in Zookeeper and copies them to the container if they exist, otherwise initpki and genconfig are run
1. Launchs the OpenVPN daemon in daemon mode
1. Starts the Python REST interface
1. Synchronisation cron job every 2 minutes


Troubleshooting
--------------

### Service

1. Review stdout and stderr from the task's logs under the `DC/OS Dashboard > Service > openvpn > running task > logs`
2. If the task is running on DC/OS, find out which agent is running the service using the DC/OS cli `dcos task | grep openvpn`
4. SSH to that agent and get a shell on the running container
```
docker ps
docker exec -it <Container ID> /bin/bash
```
5. /dcos is the working directory, `ps` should show both the openvpn daemon and the REST interface running
6. /dcos/bin/run.sh has a number of useful functions for resetting and reconfiguring the container, review the source
7. If you kill openvpn process, relaunch it manually and pass --log-append /var/log/openvpn.log you can then review connectivity issues

### Local development

If you wish to debug further, building the Docker image from the Dockerfile and amending `bin/run.sh` as follows allows you disable services for testing
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

### Zookeeper znode removal

[Zookeeper Super User credentials](https://docs.mesosphere.com/1.8/administration/installing/custom/configuration-parameters/#zk_super_credentials) must be configured on deployment of
DC/OS to allow you to delete the root openvpn znode. Setting ZK credentials is recommended as part of [DC/OS hardening](https://docs.mesosphere.com/1.9/security/hardening/).


Todo
--------------
1. The patch for zk-shell https://github.com/rgs1/zk_shell/pull/82 as managed in run.bash around line 100 needs removing when zk-shell is fixed
1. Update the /status endpoint for ovpn_status output and tie into a healthcheck
1. Update for DC/OS 1.10 and file based secrets
1. Either extend zk-shell to add auth to its params or replace with Kazoo code
1. Replace the location function which calls out to ifconfig.me as it's of no use for internal networks
