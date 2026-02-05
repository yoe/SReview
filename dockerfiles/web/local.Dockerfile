FROM debian:stable-backports
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends install \
  bs1770gain \
  ffmpeg \
  fonts-font-awesome \
  inkscape \
  libclass-type-enum-perl \
  libcryptx-perl \
  libdatetime-format-pg-perl \
  libdatetime-perl \
  libextutils-depends-perl \
  libfile-which-perl \
  libjs-bootstrap4 \
  libjs-vue \
  libmojo-pg-perl \
  libmojolicious-perl \
  libmojolicious-plugin-openapi-perl \
  libmoose-perl \
  libnet-amazon-s3-perl \
  libtest-deep-perl \
  libtext-format-perl \
  libyaml-libyaml-perl \
  perl \
  postgresql-client \
  pwgen \
  python3.11-venv \
  -y && \
  apt-get install --no-install-recommends \
  -t bookworm-backports \
  libmedia-convert-perl \
  -y

# torch without CUDA
RUN python3 -m venv /venv && /venv/bin/pip install torch --index-url https://download.pytorch.org/whl/cpu && /venv/bin/pip install openai-whisper

RUN mkdir /etc/sreview

WORKDIR /usr/share/sreview/

ADD /lib/ /usr/local/lib/site_perl/
ADD /scripts/sreview-config /usr/src/scripts/sreview-config

RUN cd /usr/src/scripts/ && ./sreview-config --action=update --set=adminpw=dev --set=adminuser=dev@dev.dev  --set=secret=INSECURE_DEV_SECRET --set=dbistring=dbi:Pg:dbname=sreviewdb\;host=db\;user=sreviewuser\;password=sreviewpassword --set=api_key=devkey --set=event=testevent

CMD ./sreview-web daemon
EXPOSE 8080
