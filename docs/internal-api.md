# SReview internal APIs

SReview containers a number of internal APIs, which are useful to know
about if you want to administer the SReview system. Additionally, if you
want to contribute to SReview, it helps to be aware of them.

The APIs are documented in POD format, but it's useful to have a bit of
an overview; that's what this document attempts to provide.

## Files API

The `SReview::Files` API provides access to media files. Any component
of the system that wants to access a file *must* use this API. This
allows for abstracting away the way in which the files are accessed. As
of this writing, implementations exist to access and detect files
directly on the filesystem (locally or via NFS), via an Amazon
S3-compatible API, via plain HTTP, via HTTP with nginx JSON indexes, and
via SSH.

### Collections

The Files API places each file in a "collection". A collection is a
logical grouping of files that can be accessed in a uniform way. For
instance, the "input directory" (as configured through the `inputglob`
configuration parameter) defines one collection.

The `SReview::Files` implementation to access files is configured at the
collection level, through the `accessmethods` configuration parameter.
This parameter should be a hash where each key is the name of a
collection to configure the collection implementation for, and the value
is the name of the implementing collection class, with the
`SReview::Files::Collection::` prefix dropped.

If the `accessmethods` configuration item does not contain a key for the
relevant collection, then the collection cannot be created and SReview
will produce an error.

SReview requires at least three collections:

1. The `input` collection contains raw files as they are received from
   the camera. The location where files in this collection are found is
   configured by the `inputglob` configuration item. For backwards
   compatibility reasons, this collection looks for files by way of an
   input glob, rather than a root URL; it is the only collection which
   requires that, but this distinction may be removed at a future point.
2. The `intermediate` collection contains the files that are served to
   the public for the review webinterface. The location where files in
   this collection are found is configured by the `pubdir` configuration
   item. For the webinterface to work, it must be served on the URL
   configured by the `vid_prefix` configuration item (which may be
   host-relative if it is served on the same hostname as the SReview
   webinterface itself).
3. The `output` collection contains the finalized files that are
   produced by SReview. The location for this collection is configured
   by the `outputdir` configuration item.
   This is the location where all transcoded files (the output of
   SReview) are written to by `sreview-transcode`; the `sreview-upload`
   script, however, *reads* files from this collection. If the
   `outputdir` is somehow directly readable over the Internet, then the
   use of `sreview-upload` is not required and the `uploading` state can
   be skipped. However, this may not be desireable, as the `direct`
   implementation (for direct filesystem access) does not use temporary
   files and writes directly to this collection, which may therefore
   result in incomplete files appearing to users.

These three collections are not optional and therefore assumed to always
be present.

If the `inject` functionality is enabled, then an extra collection, the
name of which should be specified the `inject_collection` configuration
item, is required. When doing so, an entry for the collection should be
present in the `accessmethods` configuration item, and the
`extra_collections` configuration item (which should also be a hash)
should contain a key for the same collection name with as its value the
base URL of the collection.

In some cases, it may be desireable to copy the files from one
collection to another as a way to upload scripts from the
`sreview-upload` script. In that case, the `sreview-copy` script can be
used, with relevant values in the `accessmethods` and
`extra_collections` configuration items.

### Creating objects

Creating an object is done by way of the `SReview::Files::Factory::create`
method. See the POD documentation for `SReview::Files::Factory` for details.
