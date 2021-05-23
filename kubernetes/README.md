These files allow for running SReview on a Kubernetes cluster.

TODO:

- I used this as a project to learn about Kubernetes. Most likely, I've
  made mistakes. Patches welcome!
- Use this in production. Thus far, we've only used it in test
  environments.

Instructions:
- Create a PostgreSQL database instance. Either use "postgres.yaml" to
  create one inside kubernetes, or use an external one if you already
  have that. Make sure to back up this database somehow (instructions on
  doing so is outside the scope of this documentation; please see [the
  PostgreSQL website](https://www.postgresql.org) for more details).
- Edit the "config.yaml" file to do configuration. Run `sreview-config
  dump` in the `encoder` image to get a list of all the configuration
  values with their defaults. You can set them as environment variables
  by uppercasing them and prepending `SREVIEW_`; e.g., to configure the
  `$event` value, set the environment variable `SREVIEW_EVENT`. All
  values should be encoded as JSON; this means that to encode a string,
  you should double-quote them in the YAML file:

  ```yaml
        env:
        - name: SREVIEW_EVENT
          value: '"foo"'
  ```

  ... will set the value of the `$event` configuration value to 'foo'
- Make sure to perform the following configuration steps:
  - Create some buckets in an Amazon S3-compatible object store, and
    store their access keys in the `s3_access_config` configuration
    value, and configure the `inputglob`, `pubdir` and `outputdir`
    configuration variables so they point to the correct buckets. If
    you're using minikube to test this out, the `minio.yaml` file will
    set up a pod for minio, which provides a single-container (i.e.,
    non-redundant) S3-compatible installation (see the logs of the
    container it sets up for details on the authentication, and
    optionally change them in the environment for the pod in
    `minio.yaml`). Please note that this is not safe for production,
    unless backups are taken of (at least) the data in the input bucket.
    You'll still need to create the buckets manually; the yaml file
    doesn't do that for you.
  - Make sure the bucket that the `pubdir` configuration value points to
    allows unauthenticated users to download the files there, and set the
    `vid_prefix` configuration value so that it contains the URL for
    read-only unauthenticated access to this bucket. For minio as
    configured with the `minio.yaml` file, this URL
    would be `http://sreview-storage:9000/bucketname`, with `bucketname`
    replaced by the name of the bucket in question.
  - Configure the URL that will be used by your SReview deployment in
    the `urlbase` configuration value, so that `sreview-notify` knows
    where to point to.
- Ensure that the user can access your SReview instance through a load
  balancer or an ingress or something along those lines (whichever suits
  your setup best). There is an example ingress configuration for
  `sreview.example.com` in the `master.yaml` file, but this may not suit
  your purpose.

After that, just `kubectl apply` these files.
