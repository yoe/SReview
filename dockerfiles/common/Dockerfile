FROM debian:testing
COPY *.deb /root/
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install cpanminus make /root/sreview-common*deb && apt-get clean && cpanm Class::Type::Enum
