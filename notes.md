notes.md

subprocess.check_call('$ZKCLI --run-once "cp file://{0} $ZKPATH/{1}" $ZKURL'.format(path(name), os.path.relpath(path(name),os.environ.get("CONFIG_LOCATION"))), shell=True)

echo -e "zk-shell --run-from-stdin master.mesos:2181 << EOF\nadd_auth digest admin:password\nls /richard\nEOF" | sh

curl -H "Authorization: token=$(dcos config show core.dcos_acs_token)" -X POST -d "name=richard" https://192.168.33.12:1271/client

curl -k -u admin:password -X POST -d "name=richard" https://192.168.33.12:31074/client


def testkazoo():
    acl = make_digest_acl('admin', 'password', read=True, write=True, create=True, delete=True, admin=True, all=True)
    zk = KazooClient(hosts='master.mesos:2181', default_acl=[acl])
    zk.start()
    zk.add_auth("digest", "admin:password")
    zk.ensure_path("/richard/test1")
    zk.stop()

"cmd": "/usr/bin/python -m dcos_openvpn.main",


#!/bin/bash

echo -e "zk-shell --run-from-stdin master.mesos:2181 << EOF\nadd_auth digest $OVPN_USERNAME:$OVPN_PASSWORD\n$1\nEOF" | sh


removed '/etc/openvpn/pki/issued/richard.crt'
removed '/etc/openvpn/pki/private/richard.key'
removed '/etc/openvpn/pki/reqs/richard.req'

/dcos-vpn/pki/reqs/richard.req
/dcos-vpn/pki/private/richard.key
/dcos-vpn/pki/issued/richard.crt



  "cmd": "/usr/bin/python -m dcos_openvpn.main",