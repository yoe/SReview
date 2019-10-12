FROM debian:stable
COPY *.deb /root/
RUN apt-get update && DEBIAN_FRONTENT=noninteractive apt-get -y install /root/sreview-encoder*deb /root/sreview-common*deb
