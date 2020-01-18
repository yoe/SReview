ARG ci_registry_image
ARG ci_commit_ref_slug
FROM $ci_commit_image/common:$ci_commit_ref_slug
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install /root/sreview-encoder*deb libdevel-trace-perl
