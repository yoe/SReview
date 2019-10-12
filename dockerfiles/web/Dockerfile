FROM debian:stable
COPY *.deb /root/
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install /root/sreview-web*deb /root/sreview-common*deb
ENTRYPOINT ["/usr/bin/hypnotoad","-f","/usr/bin/sreview-web"]
EXPOSE 8080
