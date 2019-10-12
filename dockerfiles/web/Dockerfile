FROM debian:stable
COPY *.deb /root
RUN apt-get update && apt-get -y install /root/sreview-web*deb /root/sreview-encoder*deb
ENTRYPOINT /usr/bin/sreview-web
