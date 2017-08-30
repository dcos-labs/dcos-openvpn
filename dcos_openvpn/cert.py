
from __future__ import absolute_import, print_function

import os
import re
import subprocess

OVPN_USERNAME = os.environ.get('OVPN_USERNAME')
OVPN_PASSWORD = os.environ.get('OVPN_PASSWORD')
CA_PASS = "nopass"


def path(name):
    return os.path.join(os.environ.get("EASYRSA_PKI", ""),
        "private/{0}.key".format(name))


def generate(name):
    subprocess.check_call(
        "source /dcos/bin/envs.sh; /dcos/bin/easyrsa build-client-full {0} nopass".format(
            name), shell=True)


def upload(name):
    subprocess.check_call('/dcos/bin/zkshrun.sh "cp file:///etc/openvpn/pki /dcos-vpn/pki true true"'.format(name), shell=True)


def output(name):
    loc = subprocess.check_output("/dcos/bin/run.sh get_location", shell=True)
    return re.sub("remote .*", loc, subprocess.check_output(
        "ovpn_getclient {0}".format(name), shell=True))


def remove(name):
    subprocess.check_call("ovpn_revokeclient {0} remove ".format(name), shell=True)
    subprocess.check_call('/dcos/bin/zkshrun.sh "rmr /dcos-vpn/pki"'.format(name), shell=True)
    subprocess.check_call('/dcos/bin/zkshrun.sh "cp file:///etc/openvpn/pki /dcos-vpn/pki true true"'.format(name), shell=True)


def test():
    subprocess.check_call('/dcos/bin/zkshrun.sh "find dcos-vpn"', shell=True)