FROM debian:stable
COPY *.deb /root/
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install /root/sreview-common*deb && apt-get clean
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends /root/sreview-master*deb
ENTRYPOINT /usr/bin/sreview-dispatch
