FROM debian:stable
COPY *.deb /root/
RUN apt-get update && apt-get -y install /root/sreview-master*deb /root/sreview-common*deb /root/sreview-detect*deb
ENTRYPOINT /usr/bin/sreview-dispatch
