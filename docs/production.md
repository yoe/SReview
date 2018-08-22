# Production examples

SReview has been used in production for the following conferences:

* FOSDEM: 2017 and 2018 edition.
* DebConf: 2017 and 2018 edition.

At FOSDEM 2017, SReview was installed on the following machines:

- review.video.fosdem.org: web interface, postgresql, gridengine master,
  gridengine exec, dispatch script
- encoder0.video.fosdem.org, encoder1.video.fosdem.org, ...: gridengine
  exec, encoder nodes
- backend0.video.fosdem.org, backend1.video.fosdem.org, ...:
  `detect_files`, storage for raw recordings (access over HTTP only)
- storage0.video.fosdem.org, storage1.video.fosdem.org, ...: NFS,
  storage for `cut_talk`, `previews`, and `transcode` output.

All machines were "bare metal" machines at a cloud hoster. Data access
to the database and the raw files was LAN-based and therefore quick.

FOSDEM 2017 was the first ever conference where SReview was used. The
code was *extremely* rough around the edges; in fact, much of the
functionality wasn't there yet, and much of what was there has since
been rewritten.

The setup for FOSDEM 2018 was very similar, but there were a few
differences:

- Everything ran from Debian packages, and we used the generic scripts
  (`sreview-transcode` rather than a custom `transcode` script, etc).
- review.video.fosdem.org was renamed to review-master.video.fosdem.org,
  and a CNAME was created for the former, for more flexibility (which we
  turned out not to need in the end, sigh).
- The NGinX-mp4 module was not used this time around to access the
  backend machines, instead we used NFS to access them.

At DebConf17, SReview was installed on the following machines:

- vittoria.debian.org: web interface, postgresql, gridengine master,
  gridengine exec, dispatch script with configuration for upload and
  notification *only* (upload script would pull from noc1st0 first and
  then publish).
- noc1st0.debconf17.debconf.org: raw recordings, all intermediate files,
  nginx (for serving preview files to reviewers), gridengine master,
  `detect_files`, NFS server for raw and intermediate files, gridengine
  exec (for `cut_talks` scripts *only*).
- encoder0.debconf17.debconf.org, encoder1.debconf17.debconf.org, ...:
  gridengine exec, encoder nodes.

vittoria is a VM that runs on Debian infrastructure at GRNET (Greece).
It is available to the DebConf video team all year.

The other machines were local hardware, borrowed for the duration of
DebConf17. They were configured to be granted access to *only* the
postgresql on vittoria.

During the conference, while the talks were in the `waiting_for_files`
through `transcoding` states, no files were copied to vittoria. Only
when the transcodes had finished were they copied (by the `uploads`
script that ran on vittoria) to vittoria, and then pushed from vittoria
to the DebConf [video archive](https://video.debian.net).

For DebConf18, the setup was very similar, but there was a major
difference: rather than having multiple machines on-site, the DebConf18
setup only had one 24-core VM with 10 TiB of storage on-site,
`storage.dc18.debconf.org`. All cutting and transcoding was done on this
machine; vittoria served the webinterface and the database, etc.

After the conference, all raw recordings were rsync'd to vittoria.

It is possible to run all components of SReview on a single host; for
small conferences, doing so is recommended.
