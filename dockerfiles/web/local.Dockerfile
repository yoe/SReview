FROM debian:stable-backports
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install perl postgresql-client ffmpeg inkscape bs1770gain libnet-amazon-s3-perl libmojolicious-perl libclass-type-enum-perl libcryptx-perl libdatetime-format-pg-perl libdatetime-perl libextutils-depends-perl libfile-which-perl libmojo-pg-perl libmoose-perl libtest-deep-perl libtext-format-perl libyaml-libyaml-perl fonts-font-awesome libjs-bootstrap4 libjs-vue libmojolicious-plugin-openapi-perl pwgen python3.11-venv && apt-get install -y --no-install-recommends -t bookworm-backports libmedia-convert-perl

# torch without CUDA
RUN python3 -m venv /venv && /venv/bin/pip install torch --index-url https://download.pytorch.org/whl/cpu && /venv/bin/pip install openai-whisper

RUN mkdir /etc/sreview

WORKDIR /usr/share/sreview/

ADD /lib/ /usr/local/lib/site_perl/
ADD /scripts/sreview-config /usr/src/scripts/sreview-config

RUN cd /usr/src/scripts/ && ./sreview-config --action=update --set=adminpw=dev --set=adminuser=dev@dev.dev  --set=secret=INSECURE_DEV_SECRET --set=dbistring=dbi:Pg:dbname=sreviewdb\;host=db\;user=sreviewuser\;password=sreviewpassword --set=api_key=devkey --set=event=testevent

CMD ./sreview-web daemon
EXPOSE 8080
