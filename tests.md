Testing

Pre
	reset ZK
	Add secrets to DC/OS

Install
	ovpn running
	python running

Auth
	Check random u:p works
	Auth on client page

Add user
	Get ovpn creds
	Check ZK upload

Revoke user
	Check container files
	Check ZK files removed

Re-install
	dcos marathon app remove /openvpn
	dcos marathon app add config.json
	Check ZK download to container
