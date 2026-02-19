"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const vm = require("node:vm");

function hasPerlAndMojoTemplate() {
  const r = spawnSync("perl", ["-MMojo::Template", "-e", "1"], {
    encoding: "utf8",
  });
  return r.status === 0;
}

function renderReviewTemplateOrSkip(t) {
  if (!hasPerlAndMojoTemplate()) {
    t.skip("perl or Mojo::Template not available");
    return null;
  }

  const templateFile = path.join(
    __dirname,
    "..",
    "..",
    "web",
    "templates",
    "review",
    "full.html.ep",
  );

  const perlProgram = String.raw`
use strict;
use warnings;
use Mojo::Template;

{
  package Talk;
  sub new {
    my ($class) = @_;
    return bless {
      nonce => 'NONCE',
      eventname => 'Event',
      title => 'Title',
      speakers => 'Speakers',
      readable_date => '2020-01-01',
      room => 'Room',
      relative_name => 'relname',
      preview_exten => 'mp4',
      state => 'preview',
      corrections => { serial => 0, audio_channel => 0 },
      comment => "",
    }, $class;
  }
  sub nonce { $_[0]->{nonce} }
  sub eventname { $_[0]->{eventname} }
  sub title { $_[0]->{title} }
  sub speakers { $_[0]->{speakers} }
  sub readable_date { $_[0]->{readable_date} }
  sub room { $_[0]->{room} }
  sub relative_name { $_[0]->{relative_name} }
  sub preview_exten { $_[0]->{preview_exten} }
  sub state { $_[0]->{state} }
  sub corrections { $_[0]->{corrections} }
  sub comment { $_[0]->{comment} }
}

sub flash { return undef; }

my $file = shift @ARGV;

my $mt = Mojo::Template->new(vars => 1, namespace => 'main');
my $talk = Talk->new();
my $out = $mt->render_file($file, {
  talk => $talk,
  vid_prefix => '/vid',
  adminspecial => 0,
});

die $out if ref $out;
print $out;
`;

  const r = spawnSync("perl", ["-e", perlProgram, templateFile], {
    encoding: "utf8",
    maxBuffer: 10 * 1024 * 1024,
  });

  if (r.status !== 0) {
    throw new Error(`Template render failed: ${r.stderr || r.stdout}`);
  }

  return r.stdout;
}

function extractInlineScript(html) {
  const matches = [...html.matchAll(/<script>([\s\S]*?)<\/script>/gi)];
  assert.ok(matches.length > 0, "expected at least one <script> in template");
  return matches[matches.length - 1][1];
}

function createDom(html) {
  const { JSDOM } = require("jsdom");

  const dom = new JSDOM(html, {
    url: "http://localhost/",
    runScripts: "outside-only",
    pretendToBeVisual: true,
  });

  const window = dom.window;
  const $ = require("jquery")(window);

  // Make slideUp/slideDown/fadeIn/fadeOut synchronous for reliable assertions.
  if ($.fx && Object.prototype.hasOwnProperty.call($.fx, "off")) {
    $.fx.off = true;
  }
  $.fn.slideUp = $.fn.hide;
  $.fn.slideDown = $.fn.show;
  $.fn.fadeOut = $.fn.hide;
  $.fn.fadeIn = $.fn.show;

  // Bootstrap popover is used by the template; we don't test it here.
  $.fn.popover = function popoverNoop() {
    return this;
  };

  // Avoid async/network.
  $.getJSON = function getJSONStub(_url, cb) {
    cb({
      start_iso: "2020-01-01T00:00:00.000Z",
      end_iso: "2020-01-01T00:02:00.000Z",
    });
  };

  return { dom, window, $ };
}

async function tick(window) {
  await new Promise((resolve) => window.setTimeout(resolve, 0));
}

async function runReviewPageInlineScript({ window, $ }, scriptSource) {
  const context = vm.createContext({
    window,
    document: window.document,
    $,
    jQuery: $,
    Intl: window.Intl,
    Date: window.Date,
    setTimeout: window.setTimeout.bind(window),
    clearTimeout: window.clearTimeout.bind(window),
  });

  vm.runInContext(scriptSource, context, { filename: "review-inline-script.js" });

  // Trigger $(document).ready handlers.
  // jQuery's ready implementation listens for DOMContentLoaded and/or load.
  window.document.dispatchEvent(new window.Event("DOMContentLoaded", { bubbles: true }));
  window.dispatchEvent(new window.Event("load"));

  // jQuery may schedule ready callbacks via setTimeout; give it a tick.
  await new Promise((resolve) => window.setTimeout(resolve, 0));
}

function isVisible(window, el) {
  return window.getComputedStyle(el).display !== "none";
}

test("review page: initial state + visibility toggles", async (t) => {
  const html = renderReviewTemplateOrSkip(t);
  if (!html) return;

  const script = extractInlineScript(html);
  const { window, $ } = createDom(html);
  await runReviewPageInlineScript({ window, $ }, script);

  const okRadio = window.document.querySelector(
    'input[name="video_state"][value="ok"]',
  );
  const notOkRadio = window.document.querySelector(
    'input[name="video_state"][value="not_ok"]',
  );

  assert.equal(okRadio.checked, true);
  assert.equal(notOkRadio.checked, false);

  // Sections controlled by video_state
  const problemsStart = window.document.getElementById("problems_with_start_time");
  const problemsEnd = window.document.getElementById("problems_with_end_time");
  const soundLegend = [...window.document.querySelectorAll("fieldset.video_has_problems legend")]
    .map((x) => x.textContent.trim());

  assert.equal(isVisible(window, problemsStart), false);
  assert.equal(isVisible(window, problemsEnd), false);
  assert.ok(soundLegend.includes("Sound"));

  // Comment log always visible
  const commentsFs = window.document.querySelector("fieldset.comments");
  assert.equal(isVisible(window, commentsFs), true);

  // Parts above the radio group are visible
  assert.equal(isVisible(window, window.document.getElementById("talk_info")), true);
  assert.equal(isVisible(window, window.document.getElementById("main_video")), true);

  // Toggle to "not_ok" should show problem sections
  $(notOkRadio).trigger("click");
  await tick(window);
  assert.equal(isVisible(window, problemsStart), true);
  assert.equal(isVisible(window, problemsEnd), true);

  // Toggle back to "ok" should hide them again
  $(okRadio).trigger("click");
  await tick(window);
  assert.equal(isVisible(window, problemsStart), false);
  assert.equal(isVisible(window, problemsEnd), false);
});

test("review page: start/end time extra video elements shown/hidden", async (t) => {
  const html = renderReviewTemplateOrSkip(t);
  if (!html) return;

  const script = extractInlineScript(html);
  const { window, $ } = createDom(html);
  await runReviewPageInlineScript({ window, $ }, script);

  // First enable problems
  $(window.document.querySelector('input[name="video_state"][value="not_ok"]')).trigger(
    "click",
  );
  await tick(window);

  const startTooEarly = window.document.querySelector(
    'input[name="start_time"][value="too_early"]',
  );
  const startTooLate = window.document.querySelector(
    'input[name="start_time"][value="too_late"]',
  );
  const startOk = window.document.querySelector(
    'input[name="start_time"][value="start_time_ok"]',
  );

  const rowStartEarly = window.document.getElementById("video_starts_too_early");
  const rowStartLate = window.document.getElementById("video_starts_too_late");

  // too early => show main video in start section
  $(startTooEarly).trigger("click");
  await tick(window);
  assert.equal(isVisible(window, rowStartEarly), true);
  assert.equal(isVisible(window, rowStartLate), false);
  assert.match(
    window.document.getElementById("video-start-early").getAttribute("src"),
    /\/main\./,
  );

  // too late => show pre video in start section
  $(startTooLate).trigger("click");
  await tick(window);
  assert.equal(isVisible(window, rowStartEarly), false);
  assert.equal(isVisible(window, rowStartLate), true);
  assert.match(
    window.document.getElementById("video-start-late").getAttribute("src"),
    /\/pre\./,
  );

  // ok => hide again
  $(startOk).trigger("click");
  await tick(window);
  assert.equal(isVisible(window, rowStartEarly), false);
  assert.equal(isVisible(window, rowStartLate), false);

  // End time
  const endTooEarly = window.document.querySelector(
    'input[name="end_time"][value="too_early"]',
  );
  const endTooLate = window.document.querySelector(
    'input[name="end_time"][value="too_late"]',
  );
  const endOk = window.document.querySelector(
    'input[name="end_time"][value="end_time_ok"]',
  );

  const rowEndEarly = window.document.getElementById("video_ends_too_early");
  const rowEndLate = window.document.getElementById("video_ends_too_late");

  $(endTooEarly).trigger("click");
  await tick(window);
  assert.equal(isVisible(window, rowEndEarly), true);
  assert.equal(isVisible(window, rowEndLate), false);
  assert.match(
    window.document.getElementById("video-end-early").getAttribute("src"),
    /\/post\./,
  );

  $(endTooLate).trigger("click");
  await tick(window);
  assert.equal(isVisible(window, rowEndEarly), false);
  assert.equal(isVisible(window, rowEndLate), true);
  assert.match(
    window.document.getElementById("video-end-late").getAttribute("src"),
    /\/main\./,
  );

  $(endOk).trigger("click");
  await tick(window);
  assert.equal(isVisible(window, rowEndEarly), false);
  assert.equal(isVisible(window, rowEndLate), false);
});

test("review page: av sync seconds input appears when needed", async (t) => {
  const html = renderReviewTemplateOrSkip(t);
  if (!html) return;

  const script = extractInlineScript(html);
  const { window, $ } = createDom(html);
  await runReviewPageInlineScript({ window, $ }, script);

  $(window.document.querySelector('input[name="video_state"][value="not_ok"]')).trigger(
    "click",
  );

  const avDelay = window.document.getElementById("av_delay");
  const avOk = window.document.querySelector('input[name="av_sync"][value="av_ok"]');
  const avAudio = window.document.querySelector(
    'input[name="av_sync"][value="av_not_ok_audio"]',
  );
  const avVideo = window.document.querySelector(
    'input[name="av_sync"][value="av_not_ok_video"]',
  );

  assert.equal(isVisible(window, avDelay), false);

  $(avAudio).trigger("click");
  await tick(window);
  assert.equal(isVisible(window, avDelay), true);
  assert.ok(window.document.querySelector('input[name="av_seconds"]'));

  $(avVideo).trigger("click");
  await tick(window);
  assert.equal(isVisible(window, avDelay), true);

  $(avOk).trigger("click");
  await tick(window);
  assert.equal(isVisible(window, avDelay), false);
});

test("review page: start/end offset calculations + overwrite + validation + submit", async (t) => {
  const html = renderReviewTemplateOrSkip(t);
  if (!html) return;

  const script = extractInlineScript(html);
  const { window, $ } = createDom(html);
  await runReviewPageInlineScript({ window, $ }, script);

  // Enable problems
  $(window.document.querySelector('input[name="video_state"][value="not_ok"]')).trigger(
    "click",
  );

  // Make jsdom video elements behave predictably
  function setVideoTimes(id, { duration, currentTime }) {
    const el = window.document.getElementById(id);
    Object.defineProperty(el, "duration", { value: duration, configurable: true });
    Object.defineProperty(el, "currentTime", { value: currentTime, writable: true, configurable: true });
    return el;
  }

  // Start time: too early uses main video currentTime as corrval
  const startTooEarly = window.document.querySelector(
    'input[name="start_time"][value="too_early"]',
  );
  $(startTooEarly).trigger("click");

  const startEarlyVideo = setVideoTimes("video-start-early", { duration: 120, currentTime: 5 });
  startEarlyVideo.currentTime = 5;
  $(window.document.getElementById("start_time_early")).trigger("click");

  assert.equal(window.document.getElementById("start_time_corrval").value, "5");
  assert.match(window.document.getElementById("msg_start_early").innerHTML, /New start time set/);

  // Overwrite with a new selection
  startEarlyVideo.currentTime = 7;
  $(window.document.getElementById("start_time_early")).trigger("click");
  assert.equal(window.document.getElementById("start_time_corrval").value, "7");

  // End time: too early uses post video currentTime as corrval
  const endTooEarly = window.document.querySelector(
    'input[name="end_time"][value="too_early"]',
  );
  $(endTooEarly).trigger("click");

  const endEarlyVideo = setVideoTimes("video-end-early", { duration: 120, currentTime: 8 });
  endEarlyVideo.currentTime = 8;
  $(window.document.getElementById("end_time_early")).trigger("click");

  assert.equal(window.document.getElementById("end_time_corrval").value, "8");
  // Ensure start corrval remains as set earlier
  assert.equal(window.document.getElementById("start_time_corrval").value, "7");

  // Validation: selecting a start point that would create < 1 minute duration should error and not store.
  // Current end offset is +8s (=> new_end 00:02:08). Set start offset to +80s => duration 48s.
  startEarlyVideo.currentTime = 80;
  $(window.document.getElementById("start_time_early")).trigger("click");

  assert.match(
    window.document.getElementById("err_start_early").innerHTML,
    /Video length must be at least 1 minute/,
  );
  // Corrval should still be the previous valid value
  assert.equal(window.document.getElementById("start_time_corrval").value, "7");

  // Submit should include offsets when valid and not be prevented.
  // Re-set to a valid start offset.
  startEarlyVideo.currentTime = 10;
  $(window.document.getElementById("start_time_early")).trigger("click");
  assert.equal(window.document.getElementById("start_time_corrval").value, "10");

  const form = window.document.getElementById("main_form");
  const submitEvent = new window.Event("submit", { cancelable: true });
  const ok = form.dispatchEvent(submitEvent);
  assert.equal(ok, true);
  assert.equal(submitEvent.defaultPrevented, false);

  assert.equal(window.document.getElementById("start_time_corrval").value, "10");
  assert.equal(window.document.getElementById("end_time_corrval").value, "8");
});
