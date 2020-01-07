$state_actions = {
  'announcing' => 'run-kube announce <%== $talkid %>',
  'cutting' => 'run-kube cut <%== $talkid %>',
  'generating_previews' => 'run-kube previews <%== $talkid %>',
  'notification' => 'run-kube notify <%== $talkid %>',
  'transcoding' => 'run-kube transcode <%== $talkid %>',
  'uploading' => 'run-kube upload <%== $talkid %>',
};

1;
