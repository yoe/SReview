package SReview::Db;

use Mojo::Pg;
use SReview::Config;

my $db;

sub selfdestruct {
	my $where = shift;
	return $db->migrations->migrate($where);
}

sub init {
	my $config = shift;
	$db = Mojo::Pg->new->dsn($config->get('dbistring'));

	$db->migrations->name('init')->from_string(<<'EOF');
-- 1 up
CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;
COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';
-- 1 down
DROP EXTENSION pgcrypto;
DROP EXTENSION plpgsql;
-- 2 up
CREATE TYPE talkstate AS ENUM (
    'waiting_for_files',
    'cutting',
    'generating_previews',
    'notification',
    'preview',
    'transcoding',
    'uploading',
    'done',
    'broken',
    'needs_work',
    'lost'
);
CREATE TYPE jobstate AS ENUM (
    'waiting',
    'scheduled',
    'running',
    'done',
    'failed'
);
-- 2 down
DROP TYPE talkstate;
DROP TYPE jobstate;
-- 3 up
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    name character varying NOT NULL,
    time_offset integer DEFAULT 0 NOT NULL
);
CREATE TABLE rooms (
    id SERIAL PRIMARY KEY,
    name character varying,
    altname character varying
);
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email character varying,
    password text,
    isadmin boolean DEFAULT false,
    room integer REFERENCES rooms(id),
    name character varying,
    isvolunteer boolean DEFAULT false
);
CREATE TABLE raw_files (
    id SERIAL PRIMARY KEY,
    filename character varying NOT NULL,
    room integer NOT NULL REFERENCES rooms(id),
    starttime timestamp with time zone,
    endtime timestamp with time zone
);
CREATE TABLE tracks (
    id SERIAL PRIMARY KEY,
    name character varying,
    email character varying,
    upstreamid character varying
);
CREATE TABLE talks (
    id SERIAL PRIMARY KEY,
    room integer NOT NULL REFERENCES rooms(id),
    slug character varying NOT NULL,
    nonce character varying DEFAULT encode(gen_random_bytes(32), 'hex'::text) NOT NULL UNIQUE,
    starttime timestamp with time zone NOT NULL,
    endtime timestamp with time zone NOT NULL,
    title character varying NOT NULL,
    event integer NOT NULL REFERENCES events(id),
    state talkstate DEFAULT 'waiting_for_files'::talkstate NOT NULL,
    progress jobstate DEFAULT 'waiting'::jobstate NOT NULL,
    comments text,
    upstreamid character varying NOT NULL,
    subtitle character varying,
    prelen interval,
    postlen interval,
    track integer REFERENCES tracks(id),
    reviewer integer REFERENCES users(id),
    perc integer,
    apologynote text,
    UNIQUE(event, slug)
);
CREATE TABLE speakers (
    id SERIAL PRIMARY KEY,
    email character varying,
    name character varying NOT NULL
);
CREATE TABLE speakers_talks (
    speaker integer REFERENCES speakers(id),
    talk integer REFERENCES talks(id),
    PRIMARY KEY (speaker, talk)
);
CREATE TABLE properties (
    id SERIAL PRIMARY KEY,
    name character varying,
    description character varying,
    helptext character varying
);
CREATE TABLE corrections (
    talk integer NOT NULL REFERENCES talks(id),
    property integer NOT NULL REFERENCES properties(id),
    property_value character varying,
    PRIMARY KEY(talk, property)
);
CREATE TABLE speakers_events (
    speaker integer NOT NULL REFERENCES speakers(id),
    event integer NOT NULL REFERENCES events(id),
    upstreamid character varying
);
-- 3 down
DROP TABLE speakers_events;
DROP TABLE corrections;
DROP TABLE properties;
DROP TABLE speakers_talks;
DROP TABLE speakers;
DROP TABLE talks;
DROP TABLE tracks;
DROP TABLE raw_files;
DROP TABLE users;
DROP TABLE rooms;
DROP TABLE events;
-- 4 up
CREATE VIEW raw_talks AS
 SELECT talks.id AS talkid,
    talks.slug,
    raw_files.id AS rawid,
    raw_files.filename AS raw_filename,
    talks.starttime AS talk_start,
    talks.endtime AS talk_end,
    raw_files.starttime AS raw_start,
    raw_files.endtime AS raw_end,
    (talks.endtime - talks.starttime) AS talks_length,
    (raw_files.endtime - raw_files.starttime) AS raw_length,
    (LEAST(raw_files.endtime, talks.endtime) - GREATEST(raw_files.starttime, talks.starttime)) AS raw_length_corrected,
    sum((LEAST(raw_files.endtime, talks.endtime) - GREATEST(raw_files.starttime, talks.starttime))) OVER (PARTITION BY talks.id) AS raw_total,
        CASE
            WHEN (raw_files.starttime < talks.starttime) THEN (talks.starttime - raw_files.starttime)
            ELSE '00:00:00'::interval
        END AS fragment_start
   FROM talks,
    raw_files
  WHERE (((((talks.starttime >= raw_files.starttime) AND (talks.starttime <= raw_files.endtime)) OR ((talks.endtime >= raw_files.starttime) AND (talks.endtime <= raw_files.endtime))) OR ((talks.starttime <= raw_files.starttime) AND (talks.endtime >= raw_files.endtime))) AND (talks.room = raw_files.room));
CREATE VIEW last_room_files AS
 SELECT raw_files.filename,
    raw_files.starttime,
    raw_files.endtime,
    (date_part('epoch'::text, raw_files.endtime) - date_part('epoch'::text, raw_files.starttime)) AS length,
    rooms.name AS room
   FROM (raw_files
     JOIN rooms ON ((raw_files.room = rooms.id)))
  WHERE ((raw_files.room, raw_files.starttime) IN ( SELECT raw_files_1.room,
            max(raw_files_1.starttime) AS max
           FROM raw_files raw_files_1
          GROUP BY raw_files_1.room));
CREATE FUNCTION speakerlist(integer) RETURNS character varying
    LANGUAGE plpgsql STABLE
    AS $_$
 DECLARE
   crsr CURSOR FOR SELECT speakers.name FROM speakers JOIN speakers_talks ON speakers.id = speakers_talks.speaker WHERE speakers_talks.talk = $1;
   row RECORD;
   curname speakers.name%TYPE;
   prevname varchar;
   retval varchar;
 BEGIN
   retval=NULL;
   prevname=NULL;
   curname=NULL;
   FOR row IN crsr LOOP
     prevname = curname;
     curname = row.name;
     IF prevname IS NOT NULL THEN
       retval = concat_ws(', ', retval, prevname);
     END IF;
   END LOOP;
   retval = concat_ws(' and ', retval, curname);
   RETURN retval;
 END;
$_$;
CREATE VIEW mailers AS
 SELECT speakers.email,
    talks.nonce,
    talks.title
   FROM ((speakers_talks
     JOIN speakers ON ((speakers_talks.speaker = speakers.id)))
     JOIN talks ON ((speakers_talks.talk = talks.id)))
  WHERE (speakers.email IS NOT NULL);
CREATE VIEW talk_list AS
 SELECT talks.id,
    talks.event AS eventid,
    events.name AS event,
    rooms.name AS room,
    speakerlist(talks.id) AS speakers,
    talks.title AS name,
    talks.nonce,
    talks.slug,
    talks.starttime,
    talks.endtime,
    talks.state,
    talks.progress,
    talks.comments,
    rooms.id AS roomid,
    talks.prelen,
    talks.postlen,
    talks.subtitle,
    talks.apologynote,
    tracks.name AS track
   FROM (((rooms
     LEFT JOIN talks ON ((rooms.id = talks.room)))
     LEFT JOIN events ON ((talks.event = events.id)))
     LEFT JOIN tracks ON ((talks.track = tracks.id)));
CREATE FUNCTION adjusted_raw_talks(integer, interval, interval) RETURNS SETOF raw_talks
    LANGUAGE plpgsql
    AS $_$
DECLARE
  talk_id ALIAS FOR $1;
  start_off ALIAS FOR $2;
  end_off ALIAS FOR $3;
BEGIN
  RETURN QUERY
    SELECT talk_id AS talkid,
           talks.slug,
           raw_files.id AS rawid,
           raw_files.filename AS raw_filename,
           talks.starttime + start_off AS talk_start,
           talks.endtime + start_off + end_off AS talk_end,
           raw_files.starttime AS raw_start,
           raw_files.endtime AS raw_end,
           (talks.endtime + start_off + end_off) - (talks.starttime + start_off) AS talk_length,
           raw_files.endtime - raw_files.starttime AS raw_length,
           LEAST(raw_files.endtime, talks.endtime + start_off + end_off) - GREATEST(raw_files.starttime, talks.starttime + start_off) AS raw_length_corrected,
           SUM(LEAST(raw_files.endtime, talks.endtime + start_off + end_off) - GREATEST(raw_files.starttime, talks.starttime + start_off)) OVER (range unbounded preceding),
           CASE
             WHEN raw_files.starttime < talks.starttime + start_off THEN talks.starttime + start_off - raw_files.starttime
             ELSE '00:00:00'::interval
           END AS fragment_start
      FROM raw_files JOIN rooms ON raw_files.room = rooms.id JOIN talks ON rooms.id = talks.room
      WHERE talks.id = talk_id
        AND ((talks.starttime + start_off) >= raw_files.starttime AND (talks.starttime + start_off) <= raw_files.endtime
            OR (talks.endtime + start_off + end_off) >= raw_files.starttime AND (talks.endtime + start_off + end_off) <= raw_files.endtime
            OR (talks.starttime + start_off) <= raw_files.starttime AND (talks.endtime + start_off + end_off) >= raw_files.endtime)
      UNION
    SELECT
        -1 AS talkid, -- use -1 to mark that this is the pre video
        talks.slug,
        raw_files.id AS rawid,
        raw_files.filename AS raw_filename,
        talks.starttime + start_off - '00:20:00'::interval AS talk_start,
        talks.starttime + start_off AS talk_end,
        raw_files.starttime AS raw_start,
        raw_files.endtime AS raw_end,
        '00:20:00'::interval AS talk_length,
        raw_files.endtime - raw_files.starttime AS raw_length,
        LEAST(raw_files.endtime, talks.starttime + start_off) - GREATEST(raw_files.starttime, talks.starttime + start_off - '00:20:00'::interval) AS raw_length_corrected,
        SUM(LEAST(raw_files.endtime, talks.starttime + start_off) - GREATEST(raw_files.starttime, talks.starttime + start_off - '00:20:00'::interval)) OVER (range unbounded preceding),
        CASE
          WHEN raw_files.starttime < talks.starttime + start_off - '00:20:00'::interval THEN (talks.starttime + start_off - '00:20:00'::interval) - raw_files.starttime
          ELSE '00:00:00'::interval
        END AS fragment_start
      FROM raw_files JOIN rooms ON raw_files.room = rooms.id JOIN talks ON rooms.id = talks.room
      WHERE talks.id = talk_id
        AND ((talks.starttime + start_off - '00:20:00'::interval) >= raw_files.starttime AND (talks.starttime + start_off - '00:20:00'::interval) <= raw_files.endtime
            OR (talks.starttime + start_off) >= raw_files.starttime AND (talks.starttime + start_off) <= raw_files.endtime
            OR (talks.starttime + start_off - '00:20:00'::interval) <= raw_files.starttime AND (talks.endtime + start_off) >= raw_files.endtime)
      UNION
    SELECT
        -2 AS talkid, -- use -2 to mark that this is the post video
        talks.slug,
        raw_files.id AS rawid,
        raw_files.filename AS raw_filename,
        talks.endtime + start_off + end_off AS talk_start,
        talks.endtime + start_off + end_off + '00:20:00'::interval AS talk_end,
        raw_files.starttime AS raw_start,
        raw_files.endtime AS raw_end,
        '00:20:00'::interval AS talk_length,
        raw_files.endtime - raw_files.starttime AS raw_length,
        LEAST(raw_files.endtime, talks.endtime + start_off + end_off + '00:20:00'::interval) - GREATEST(raw_files.starttime, talks.endtime + start_off + end_off) AS raw_length_corrected,
        SUM(LEAST(raw_files.endtime, talks.endtime + start_off + end_off + '00:20:00'::interval) - GREATEST(raw_files.starttime, talks.endtime + start_off + end_off)) OVER (range unbounded preceding),
        CASE
          WHEN raw_files.starttime < talks.endtime + start_off + end_off THEN talks.endtime + start_off + end_off - raw_files.starttime
          ELSE '00:00:00'::interval
        END AS fragment_start
      FROM raw_files JOIN rooms ON raw_files.room = rooms.id JOIN talks ON rooms.id = talks.room
      WHERE talks.id = talk_id
        AND ((talks.endtime + start_off + end_off) >= raw_files.starttime AND (talks.endtime + start_off + end_off) <= raw_files.endtime
            OR (talks.endtime + start_off + end_off + '00:20:00'::interval) >= raw_files.starttime AND (talks.endtime + start_off + end_off + '00:20:00'::interval) <= raw_files.endtime
            OR (talks.endtime + start_off + end_off) <= raw_files.starttime AND (talks.endtime + start_off + end_off + '00:20:00'::interval) >= raw_files.endtime);
END $_$;
CREATE FUNCTION corrections_redirect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  corrs RECORD;
BEGIN
  FOR corrs IN SELECT * FROM corrections WHERE talk = NEW.talk AND property = NEW.property LOOP
    UPDATE corrections SET property_value = NEW.property_value WHERE talk = NEW.talk AND property = NEW.property;
    RETURN NULL;
  END LOOP;
  RETURN NEW;
END $$;
CREATE FUNCTION speakeremail(integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
  crsr CURSOR FOR SELECT speakers.email, speakers.name FROM speakers JOIN speakers_talks ON speakers.id = speakers_talks.speaker WHERE speakers_talks.talk = $1;
  row RECORD;
  retval VARCHAR;
BEGIN
  retval = NULL;
  FOR row IN crsr LOOP
    retval = concat_ws(', ', retval, row.name || ' <' || row.email || '>');
  END LOOP;
  RETURN retval;
END; $_$;
CREATE FUNCTION state_next(talkstate) RETURNS talkstate
    LANGUAGE plpgsql
    AS $_$
declare
  enumvals talkstate[];
  startval alias for $1;
begin
  enumvals := enum_range(startval, NULL);
  return enumvals[2];
end $_$;
CREATE TRIGGER corr_redirect_conflict BEFORE INSERT ON corrections FOR EACH ROW EXECUTE PROCEDURE corrections_redirect();
-- 4 down
DROP TRIGGER corr_redirect_conflict;
DROP FUNCTION state_next(talkstate);
DROP FUNCTION corrections_redirect();
DROP FUNCTION adjusted_raw_talks(integer, interval, interval);
DROP FUNCTION speakeremail(integer);
DROP FUNCTION speakerlist(integer);
DROP VIEW talk_list;
DROP VIEW mailers;
DROP VIEW last_room_files;
DROP VIEW raw_talks;
-- 5 up
INSERT INTO properties(name, description, helptext) VALUES('length_adj', 'Length adjustment', 'Set a relative adjustment value for the talk here, specified in seconds. To shorten the talk length, enter a negative value; to increase the talk length, enter a positive value');
INSERT INTO properties(name, description, helptext) VALUES('offset_audio', 'Audio offset', 'Use for fixing A/V sync issues. Positive delays audio, negative delays video. Seconds; may be fractional.');
INSERT INTO properties(name, description, helptext) VALUES('audio_channel', 'Audio channel', 'Use 0 for the main channel, 1 for the alternate channel, or 2 for both channels mixed together');
INSERT INTO properties(name, description, helptext) VALUES('offset_start', 'Time offset', 'Use to adjust the time position of this talk. Negative values move the start to earlier in time, positive to later. Note that both start and end position are updated; if the end should not be updated, make sure to also set the "Length adjustment" value. Seconds; may be fractional.');
-- 5 down
DELETE FROM properties WHERE name IN ('length_adj', 'offset_audio', 'audio_channel', 'offset_start');
EOF

	return $db->migrations->migrate;
}

1;
