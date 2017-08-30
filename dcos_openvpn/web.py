
from __future__ import absolute_import, print_function

import os
import json
import re
import sys

from flask import Flask
from flask_basicauth import BasicAuth
from webargs import Arg
from webargs.flaskparser import use_args

from . import cert

app = Flask(__name__)

app.config['BASIC_AUTH_USERNAME'] = os.environ.get('OVPN_USERNAME')
app.config['BASIC_AUTH_PASSWORD'] = os.environ.get('OVPN_PASSWORD')
basic_auth = BasicAuth(app)
ovpn_user = os.environ.get('OVPN_USERNAME')
ovpn_pass = os.environ.get('OVPN_PASSWORD')


@app.route("/")
def root():
    return "ok"


@app.route("/status")
def status():
    return "ok"


@app.route("/test")
@basic_auth.required
def test():
    print(ovpn_user, file=sys.stderr)
    print(ovpn_pass, file=sys.stderr)
    cert.test()
    return "test"


@app.route("/client", methods=["POST"])
@basic_auth.required
@use_args({
    'name': Arg(str, required=True,
        validate=lambda x: bool(re.match("^[a-zA-Z\-0-9]+$", x)))
})
def create_client(args):
    if os.path.exists(cert.path(args.get("name"))):
        return json.dumps({ "type": "error", "msg": "client exists" }), 400

    cert.generate(args.get("name"))
    cert.upload(args.get("name"))

    return cert.output(args.get("name"))


@app.route("/client/<name>", methods=["DELETE"])
@basic_auth.required
def remove_client(name):
    cert.remove(name)

    return json.dumps({ "type": "status", "msg": "success" })
