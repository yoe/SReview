# Production examples

SReview has been used in production for the following conferences:

* FOSDEM: Every edition since the 2017 edition
* DebConf: Every edition since the 2017 edition
* A few mini-debconfs: 2017 Cambridge, 2018 Hamburg, most mini-debconfs
  since.
* OSW.za: 2019 edition

These are all very different conferences; some are massive multi-room
events where it is impossible for one person or one team to review
everything; others are much smaller events where doing so is definitely
possible.

What follows are a few descriptions of potential hosting scenarios for
all of the possible events. You can use these, or not; SReview is very
flexible, so it's not required to follow the potential scenarios.

## Small conferences (one room)

e.g., mini-debconf.

Host everything on a single node.

If there is no formal schedule website, create the event in the
database, create an admin user, and then log in to the system using that
admin user. You can manually add all talks to the database.

If there is a formal schedule website, configure sreview-import and let
it run from cron.

As long as the formal schedule has a unique ID for every talk that does
not change if any other metadata of the talk (such as the title, time,
or list of speakers) changes, this is safe to do and won't interfere
with the rest of the system.

Set the `$anonreviews` configuration parameter to a trueish value and
open the `/overview` page on the SReview webinterface. Follow the links
to do review.

Optionally set up a notification system through `sreview-notify` (e.g.,
email or an IRC bot) to be notified when a talk is waiting for you (or
just refresh the overview page every once in a while).

Optionally configure a batch scheduling system (such as gridengine) to
schedule jobs. Alternatively, just have `sreview-dispatch` run the
per-state scripts directly. Note though that the `sreview-transcode`
jobs take a *lot* of time to finish, so either accept that some reviews
will have to wait, or don't enable `sreview-transcode` until everything
has been reviewed.

## Medium conferences (a handful of rooms)

e.g., DebConf, OSW.za

Host the database server and the webserver on a single node.

Configure a batch scheduling system (such as gridengine)

Configure a few worker nodes that are connected to your batch scheduling
system and can execute jobs. Make sure they are able to read from and
write to the `SReview::Files` collections configured in `$inputglob`
(read-only), `$workdir` (read/write), and `$outputdir` (read/write).

Make sure that all assets required by all jobs (e.g., `config.pm`,
credits templates, etc) are available on all worker nodes (either
through NFS or by syncing them through a config management system)

If you have a team that is large enough to do reviews, set the
`$anonreviews` configuration parameter to a trueish value and set up a
notification system through `sreview-notify` to be informed when talks
are available for review (e.g., through an IRC bot or some such).

## Large conferences (many rooms)

e.g., FOSDEM

Host the database server on a single node.

Configure a batch scheduling system (such as gridengine)

Ensure that you have the email addresses of all speakers and room or
track managers, and make sure that they are configured in the database.

Set up `sreview-notify` to send out email notifications. Notifications
will be sent to speakers, with room/track managers in Cc.

Set the `$anonreviews` configuration parameter to a falsy value. This
makes the `/overview` page no longer link through to the reviews; you
will need the review URL (which is sent to reviewers through the
notification email)

Set up a batch scheduling system (such as gridengine).

Configure a config management system so you are able to add and remove
worker nodes to the system when load increases/decreases

When review by speakers is dying down (which will eventually happen),
search for volunteers amongst your attendees or team members and hand
out non-admin accounts. These users will be given 5 talks to review
each.

Eventually you will need to finish the last handful of talks yourself.
