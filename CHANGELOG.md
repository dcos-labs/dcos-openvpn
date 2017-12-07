Changelog
===============

0.0.0-2.0 - 7th December 2017

- Added synchronisation of the PKI (users, certificates and keys) between multiple running instances
- Enabled >1 instances to be started at the same time and match their local data
- Cleaned up the output to stdout
- Refactored a number of functions in run.sh to improve robustness
- Increased CPU resource from 0.1 to 1.0 due to DC/OS 1.10 now enforcing CPU usage - required for key generation.
- Fixed https://github.com/dcos-labs/dcos-openvpn/issues/13
- Improved the function to find the public address
- Fixed the hostports in the marathon.json

0.0.0-1.0 - 12th September 2017

- Changed znode path from dcos-vpn to openvpn
- Updated notes on znode ACL management
- Bumped the version number which should have happened in the last release to reflect the change in functionality.  This is still a preview release

0.0.0-0.2 - 31st August 2017

- Added Flask-BasicAuth for the REST interface
- Enabled TLS in Flask and linked to the openvpn SSL assets
- Configured an ACL on the /dcos-vpn Zookeeper znode to protect assets
- Added full synchronisation and cleanup of assets to and from Zookeeper
- Added correct revocation of clients
- Merged openvpn and openvpn-admin functionality, openvpvn-admin is now deprecated
- Refactored bin/run.sh and added helper functions
- Moved source repository from github.com/mesosphere to github.com/dcos-labs
