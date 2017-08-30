FROM kylemanna/openvpn

MAINTAINER Richard Shaw <rshaw@mesosphere.com>

RUN apk -U add ca-certificates python python-dev py-setuptools alpine-sdk libffi libffi-dev openssl-dev

COPY . /dcos

WORKDIR /dcos
RUN ["/usr/bin/python", "setup.py", "install"]
RUN apk del alpine-sdk && \
    apk fix openssl && \
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/*
EXPOSE 5000 1194/tcp 1194/udp
CMD ["bin/run.sh", "run_server"]