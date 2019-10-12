FROM debian:stable
COPY *.deb /root/
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends /root/sreview-master*deb /root/sreview-common*deb /root/sreview-detect*deb
ENTRYPOINT /usr/bin/sreview-dispatch
