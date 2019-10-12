FROM debian:stable
COPY *.deb /root/
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install /root/sreview-encoder*deb /root/sreview-common*deb
