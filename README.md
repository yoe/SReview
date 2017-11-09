# SReview

This SReview, a video review system. It takes input files, stores
their lengths in a database, combines those lengths and their starttime
with a schedule it has of an event to see which talks are fully
recorded, and creates a preview. After that, magic happens, and
eventually a fully transcoded quality video rolls out of the system.

Note that while SReview has been used in production for [FOSDEM
2017](https://fosdem.org/2017) and [DebConf
2017](https://debconf17.debconf.org), there is still some missing functionality
in some areas. Patches welcome! :-)

## States

SReview is fairly minimalistic; it tries to assume as little as possible
about video workflow. There are, however, state machines that you should be
aware of. First, there is the main state:

    waiting_for_files
    cutting
    generating_previews
    notification
    preview
    transcoding
    uploading
    done
    broken
    needs_work
    lost

Next, there is the job state:

    waiting
    scheduled
    running
    done
    failed

Every talk is in one of the main states as well as in one of the job. The
following list explains what each of the main states means:

- `waiting_for_files`: no files (or not all of them) have been found as of yet.
  Talks should initially be in this state.
- `cutting`: the `cut_talk` script
- `generating_previews`: the `previews` script
- `notification`: a notification needs to be sent to the user responsible for
  reviewing the talk. This may be the speaker, or someone else.
- `preview`: the notification was sent. This talk is now ready for
  review by a human being (the webinterface is necessary for this step).
- `transcoding`: the `transcode` script is running, or scheduled to
  start.
- `uploading`: the files are being uploaded.
- `done`: the talk has been fully completed, all files should be
  published.
- `broken`: SReview will not automatically switch a talk to this state,
  but it can be used to mark talks that are lost forever and should not
  be considered anymore.
- `needs_work`: Refinement of `broken`. Can be used by an administrator
  to mark recordings that need larger amounts of work, but that may be
  fixed eventually.
- `lost`: Refinement of `broken`. Can be used by an administrator to
  confirm that a recording is broken and cannot be usefully released.

The job states, then, mean:

- `waiting`: it's waiting for the dispatch script to do something.
- `scheduled`: the script was picked up by the dispatch script, and has
  been put into the job scheduler's queue. If a slot is available, it
  will be started almost immediately; if not, it may need to wait until
  that's done.
- `running`: the script is now active and running.
- `done : the script finished successfully
- `failed`: the script did *not* finish successfully (note: when that
  hapens, it doesn't always go into this state, currently).

## Components

SReview consists of two major components: a webinterface (written in
Perl with Mojolicious), and a backend which consists of another set of
perl scripts.

To run the webinterface in a test environment, copy the
`config.pl.template` file in the web directory to `config.pl`, edit it,
run "./sreview daemon", and browse to the URL given. To run the
webinterface in production, see
[Mojo::Server::Hypnotoad](http://mojolicious.org/perldoc/Mojo/Server/Hypnotoad)
(or some of the other guides over there).

To run the backend, it is recommended that you install gridengine first.
In theory, the backend *should* work without gridengine, but that is not
tested. Additionally, you will then need to run a dispatcher per CPU,
rather than having just one dispatcher in the whole network (which is
annoying).

Once gridengine has been installed, copy the `config.pl.template` file
in the scripts directory to `config.pl`, edit it, and run `perl
dispatch`.

If you want to modify the output formats, you should edit the
`transcode` script where you can add and/or remove ffmpeg command lines.

If you want to modify the look and feel of the webinterface, you should
edit the files in the web/templates directory.

If you have any issues with SReview, please file an issue (or better
yet, a pull request) on the github issue tracker.

# Further reading

See the [documentation](docs/)
