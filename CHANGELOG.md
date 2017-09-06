Changelog
===============

0.0.0-0.2 - Released 31st August 2017

- Added Flask-BasicAuth for the REST interface
- Enabled TLS in Flask and linked to the openvpn SSL assets
- Configured an ACL on the /openvpn Zookeeper znode to protect assets
- Added full synchronisation and cleanup of assets to and from Zookeeper
- Added correct revocation of clients
- Merged openvpn and openvpn-admin functionality, openvpvn-admin is now deprecated
- Refactored bin/run.sh and added helper functions
- Moved source repository from github.com/mesosphere to github.com/dcos-labs
