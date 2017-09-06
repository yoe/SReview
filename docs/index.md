# Sreview documentation

Welcome to Sreview, a video review and transcoding system.

Sreview has two major modes of operation: in anonymous mode, the
"overview" page contains links to the review forms. In the notification
mode, the "overview" page does not contain those links, and instead
email notifications are sent out to reviewers that contain them.

## Reviewing

If you received an email stating that your talk is ready for review, but
when you followed the link and it showed that it was *not* ready for
review, then do not despair! It probably just means that someone else
did some review already. You'll notice that there may have been a few
people in Cc on the initial notification email. Additionally, people
with administration logon credentials may review any talk, even if they
didn't get the notification email.

### The webform

The review form shows three video elements; one large video, and two
small ones. The large video should contain *just* the talk that this
video should contain, plus possibly an introduction at the start and the
questions at the end, but no more and no less than that.

The two smaller video elements above the large video element contain
*context* video; the twenty minutes before and the twenty minutes after
the large video element. These may be helpful should the main video
start too late or stop too soon, and are re-cut whenever the main video
is re-cut (so the end of the pre video should always be *just* before
the start of the main video).

Below the three video elements is a web form where you can decide what
to do. Read on.

### If all is well...

If you review the recording, and all is well, just select the option
labeled "This preview looks OK, please transcode it at high quality and
release it" in the webform and submit it. Everything else will now
happen automatically. You're done!

### If there are some problems...

If you see a problem, and it's something that one of the options in the
"Common fixes" section of the webform could take care of, then first
select the "This preview has some issues" radio button. Then, modify the
relevant options in that section of the webform.

There are some javascript buttons on the review page that will help you
adjust the start and length of the talk; just play the relevant video
until the correct point has been reached. You may wish to pause it
(although that's not strictly necessary). Once you're happy with your
position, click the "Take start point" button under that video to make
*that* point be the start of the video; or click the "Take end point"
button to make *that* point be the end of the video.

Once you've made all the changes you think are needed, hit the "OK"
button at the bottom of the page. Your talk will now be re-cut; once
that has finished, it will be available for review again, (and if
sreview is running in notification mode, you'll get another notification
email). You can check the new cut, make any more changes as needed, and
re-submit the talk. Rinse, repeat, until all is well. Then re-read the
"If all is well" section, above.

If you see a problem that can *not* be fixed by any of the options in
the "Common fixes" section, then you can select the "This preview has
the following issues not covered by the above" option in the webform,
and explain what's wrong with it in the textarea below that. Once you've
submitted the form, your talk will now be placed in the "broken" state.
If you change your mind, you can always choose the 'Do not make changes,
do not notify video team; set the state back to "preview"' option. You
can then go back to reviewing, as usual. Alternatively, you can probably
also talk to the maintainers of your Sreview instance, if they told you
how to contact them in the notification email.

Thanks for reviewing!

## Further documentation

There is a document about the [components](components) of SReview. It
should only be necessary to read it if you want to install your own copy
of SReview, not for reviewing.
