These files allow for running SReview on a Kubernetes cluster.

TODO:

- Actually test this on a real kubernetes cluster. It (seems to) work on
  minikube on my laptop, that's all I can say.
- I used this as a project to learn about Kubernetes. Most likely, I've
  made mistakes. Patches welcome!

Instructions:
- Create three persistent volumes claims:
  - The first should have ReadWriteOnce permissions, and be called
    "postgresdata". It stores the PostgreSQL database's data and should
    be backed up.
  - The second should have ReadOnlyMany permissions, be called
    "inputdata", and is to contain the raw recordings. NOTE: SReview
    does not consider itself with how these files end up on this volume;
    it is assumed that this happens out of band. However, the format is
    important, and should (by default) be in the format
    <room>/<date>/<time>.<container>, e.g.,
    mainroom/2020-01-08/10:00:00.mp4. This can be configured through the
    `inputglob` and `parse_re` configuration values. You can configure
    these either by shipping a file `/etc/sreview/config.pm` to the
    `detect` cron job, or by specifying them as the `SREVIEW_INPUTGLOB`
    and `SREVIEW_PARSE_RE` environment variables to that job.
  - The third should have ReadWriteMany permissions, be called
    "outputdata", and is where the output of SReview will end up on.

You should either back up the postgresdata volume, or take periodic
SQL snapshots of the postgres database by way of `pg_dump`. You should
ensure that you have a backup copy of the raw recordings, too, either by
backing up the persistent volume or by backing them up outside of the
cloud infrastructure you use.

Given the data on the first two volumes, it is possible to rebuild all
of the output, but obviously that will take CPU power
