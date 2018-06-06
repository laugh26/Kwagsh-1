# daemon runs in the background
# run something like tail /var/log/kwagshd/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/kwagshd:/var/lib/qwertycoind -v $(pwd)/wallet:/home/qwertycoin --rm -ti qwertycoin:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG KWAGSH_VERSION=v2.0.0
ENV KWAGSH_VERSION=${QWERTYCOIN_VERSION}

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-4.9 \
      g++-4.9 \
      git cmake \
      libboost-all-dev && \
    git clone https://github.com/kwagsh-org/qwertycoin.git /src/qwertycoin && \
    cd /src/kwagsh && \
    git checkout $KWAGSH_VERSION && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/kwagshd /usr/local/bin/qwertycoind && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/simplewallet /usr/local/bin/simplewallet && \
    cp src/miner /usr/local/bin/miner && \
    cp src/connectivity_tool /usr/local/bin/connectivity_tool && \
    strip /usr/local/bin/kwagshd && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/simplewallet && \
    strip /usr/local/bin/miner && \
    strip /usr/local/bin/connectivity_tool && \
    cd / && \
    rm -rf /src/kwagsh && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost-all-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# setup the kwagshd service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/kwagshd qwertycoind && \
    useradd -s /bin/bash -m -d /home/kwagsh qwertycoin && \
    mkdir -p /etc/services.d/kwagshd/log && \
    mkdir -p /var/log/kwagshd && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/kwagshd/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/kwagshd/run && \
    echo "cd /var/lib/kwagshd" >> /etc/services.d/qwertycoind/run && \
    echo "export HOME /var/lib/kwagshd" >> /etc/services.d/qwertycoind/run && \
    echo "s6-setuidgid kwagshd /usr/local/bin/qwertycoind" >> /etc/services.d/qwertycoind/run && \
    chmod +x /etc/services.d/kwagshd/run && \
    chown nobody:nogroup /var/log/kwagshd && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/kwagshd/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/kwagshd/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/kwagshd" >> /etc/services.d/qwertycoind/log/run && \
    chmod +x /etc/services.d/kwagshd/log/run && \
    echo "/var/lib/kwagshd true qwertycoind 0644 0755" > /etc/fix-attrs.d/qwertycoind-home && \
    echo "/home/kwagsh true qwertycoin 0644 0755" > /etc/fix-attrs.d/qwertycoin-home && \
    echo "/var/log/kwagshd true nobody 0644 0755" > /etc/fix-attrs.d/qwertycoind-logs

VOLUME ["/var/lib/kwagshd", "/home/qwertycoin","/var/log/qwertycoind"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/kwagsh export HOME /home/qwertycoin s6-setuidgid qwertycoin /bin/bash"]