FROM kylemanna/openvpn

MAINTAINER Richard Shaw <rshaw@mesosphere.com>

RUN apk -U add ca-certificates python python-dev \
    py-setuptools alpine-sdk libffi libffi-dev openssl-dev \
    haveged

WORKDIR /dcos
RUN haveged -n 100g -f - | dd of=/dev/null
COPY . /dcos
RUN ["/usr/bin/python", "setup.py", "install"]
RUN apk del alpine-sdk && \
    apk fix openssl && \
    rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/*
EXPOSE 5000/tcp 1194/udp
CMD ["bin/run.sh", "run_server"]
