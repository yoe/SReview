package SReview::Db;

use Mojo::Pg;
use SReview::Config;
use SReview::Config::Common;

my $config = SReview::Config->new('./config.cf');

SReview::Config::Common::setup($config);

my $db = Mojo::Pg->new->dsn($config->get('dbistring'));

$db->migrations->name('init')->from_string(<<EOF)->migrate;
-- 1 up
CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;
COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';
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
SET default_with_oids = false;
CREATE TABLE raw_files (
    id integer NOT NULL,
    filename character varying NOT NULL,
    room integer NOT NULL,
    starttime timestamp with time zone,
    endtime timestamp with time zone
);
CREATE TABLE talks (
    id integer NOT NULL,
    room integer NOT NULL,
    slug character varying NOT NULL,
    nonce character varying DEFAULT encode(gen_random_bytes(32), 'hex'::text) NOT NULL,
    starttime timestamp with time zone NOT NULL,
    endtime timestamp with time zone NOT NULL,
    title character varying NOT NULL,
    event integer NOT NULL,
    state talkstate DEFAULT 'waiting_for_files'::talkstate NOT NULL,
    progress jobstate DEFAULT 'waiting'::jobstate NOT NULL,
    comments text,
    upstreamid character varying NOT NULL,
    subtitle character varying,
    prelen interval,
    postlen interval,
    track integer,
    reviewer integer
);

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
CREATE TABLE corrections (
    talk integer NOT NULL,
    property integer NOT NULL,
    property_value character varying
);
CREATE TABLE events (
    id integer NOT NULL,
    name character varying NOT NULL,
    time_offset integer DEFAULT 0 NOT NULL
);
CREATE SEQUENCE events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE events_id_seq OWNED BY events.id;
CREATE TABLE files (
    id integer NOT NULL,
    type integer NOT NULL,
    talk integer NOT NULL,
    "exists" boolean DEFAULT false NOT NULL,
    may_build boolean DEFAULT false NOT NULL
);
CREATE SEQUENCE files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE files_id_seq OWNED BY files.id;
CREATE TABLE filetypes (
    id integer NOT NULL,
    description character varying NOT NULL,
    name_template character varying,
    is_preview boolean DEFAULT false NOT NULL
);
CREATE SEQUENCE filetypes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE filetypes_id_seq OWNED BY filetypes.id;
CREATE TABLE rooms (
    id integer NOT NULL,
    name character varying,
    email character varying,
    altname character varying
);
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
CREATE TABLE speakers (
    id integer NOT NULL,
    email character varying,
    name character varying NOT NULL,
    upstreamid character varying
);
CREATE TABLE speakers_talks (
    speaker integer NOT NULL,
    talk integer NOT NULL
);
CREATE VIEW mailers AS
 SELECT speakers.email,
    talks.nonce,
    talks.title
   FROM ((speakers_talks
     JOIN speakers ON ((speakers_talks.speaker = speakers.id)))
     JOIN talks ON ((speakers_talks.talk = talks.id)))
  WHERE (speakers.email IS NOT NULL);
CREATE TABLE properties (
    id integer NOT NULL,
    name character varying,
    description character varying
);
CREATE SEQUENCE properties_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE properties_id_seq OWNED BY properties.id;
CREATE SEQUENCE raw_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE raw_files_id_seq OWNED BY raw_files.id;
CREATE SEQUENCE rooms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE rooms_id_seq OWNED BY rooms.id;
CREATE SEQUENCE speakers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE speakers_id_seq OWNED BY speakers.id;
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
    talks.comments,
    rooms.id AS roomid,
    talks.prelen,
    talks.postlen,
    talks.subtitle
   FROM ((rooms
     LEFT JOIN talks ON ((rooms.id = talks.room)))
     LEFT JOIN events ON ((talks.event = events.id)));
CREATE SEQUENCE talks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE talks_id_seq OWNED BY talks.id;
CREATE TABLE tracks (
    id integer NOT NULL,
    name character varying,
    email character varying,
    upstreamid character varying
);
CREATE SEQUENCE tracks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE tracks_id_seq OWNED BY tracks.id;
CREATE TABLE users (
    id integer NOT NULL,
    email character varying,
    password text,
    isadmin boolean DEFAULT false,
    room integer,
    name character varying,
    isvolunteer boolean DEFAULT false
);
CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE users_id_seq OWNED BY users.id;
ALTER TABLE ONLY events ALTER COLUMN id SET DEFAULT nextval('events_id_seq'::regclass);
ALTER TABLE ONLY files ALTER COLUMN id SET DEFAULT nextval('files_id_seq'::regclass);
ALTER TABLE ONLY filetypes ALTER COLUMN id SET DEFAULT nextval('filetypes_id_seq'::regclass);
ALTER TABLE ONLY properties ALTER COLUMN id SET DEFAULT nextval('properties_id_seq'::regclass);
ALTER TABLE ONLY raw_files ALTER COLUMN id SET DEFAULT nextval('raw_files_id_seq'::regclass);
ALTER TABLE ONLY rooms ALTER COLUMN id SET DEFAULT nextval('rooms_id_seq'::regclass);
ALTER TABLE ONLY speakers ALTER COLUMN id SET DEFAULT nextval('speakers_id_seq'::regclass);
ALTER TABLE ONLY talks ALTER COLUMN id SET DEFAULT nextval('talks_id_seq'::regclass);
ALTER TABLE ONLY tracks ALTER COLUMN id SET DEFAULT nextval('tracks_id_seq'::regclass);
ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);
ALTER TABLE ONLY corrections
    ADD CONSTRAINT corrections_pkey PRIMARY KEY (talk, property);
ALTER TABLE ONLY events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);
ALTER TABLE ONLY files
    ADD CONSTRAINT files_pkey PRIMARY KEY (id);
ALTER TABLE ONLY filetypes
    ADD CONSTRAINT filetypes_pkey PRIMARY KEY (id);
ALTER TABLE ONLY properties
    ADD CONSTRAINT properties_pkey PRIMARY KEY (id);
ALTER TABLE ONLY raw_files
    ADD CONSTRAINT raw_files_pkey PRIMARY KEY (id);
ALTER TABLE ONLY rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (id);
ALTER TABLE ONLY speakers
    ADD CONSTRAINT speakers_pkey PRIMARY KEY (id);
ALTER TABLE ONLY speakers_talks
    ADD CONSTRAINT speakers_talks_pkey PRIMARY KEY (speaker, talk);
ALTER TABLE ONLY talks
    ADD CONSTRAINT talks_nonce_key UNIQUE (nonce);
ALTER TABLE ONLY talks
    ADD CONSTRAINT talks_pkey PRIMARY KEY (id);
ALTER TABLE ONLY talks
    ADD CONSTRAINT talks_slug_event_key UNIQUE (slug, event);
ALTER TABLE ONLY tracks
    ADD CONSTRAINT tracks_pkey PRIMARY KEY (id);
ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);
CREATE TRIGGER corr_redirect_conflict BEFORE INSERT ON corrections FOR EACH ROW EXECUTE PROCEDURE corrections_redirect();
ALTER TABLE ONLY corrections
    ADD CONSTRAINT corrections_property_fkey FOREIGN KEY (property) REFERENCES properties(id);
ALTER TABLE ONLY corrections
    ADD CONSTRAINT corrections_talk_fkey FOREIGN KEY (talk) REFERENCES talks(id);
ALTER TABLE ONLY files
    ADD CONSTRAINT files_talk_fkey FOREIGN KEY (talk) REFERENCES talks(id);
ALTER TABLE ONLY files
    ADD CONSTRAINT files_type_fkey FOREIGN KEY (type) REFERENCES filetypes(id);
ALTER TABLE ONLY raw_files
    ADD CONSTRAINT raw_files_room_fkey FOREIGN KEY (room) REFERENCES rooms(id);
ALTER TABLE ONLY speakers_talks
    ADD CONSTRAINT speakers_talks_speaker_fkey FOREIGN KEY (speaker) REFERENCES speakers(id);
ALTER TABLE ONLY speakers_talks
    ADD CONSTRAINT speakers_talks_talk_fkey FOREIGN KEY (talk) REFERENCES talks(id);
ALTER TABLE ONLY talks
    ADD CONSTRAINT talks_event_fkey FOREIGN KEY (event) REFERENCES events(id);
ALTER TABLE ONLY talks
    ADD CONSTRAINT talks_reviewer_fkey FOREIGN KEY (reviewer) REFERENCES users(id);
ALTER TABLE ONLY talks
    ADD CONSTRAINT talks_room_fkey FOREIGN KEY (room) REFERENCES rooms(id);
ALTER TABLE ONLY talks
    ADD CONSTRAINT talks_track_fkey FOREIGN KEY (track) REFERENCES tracks(id);
ALTER TABLE ONLY users
    ADD CONSTRAINT users_room_fkey FOREIGN KEY (room) REFERENCES rooms(id);
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;
-- 1 down
DROP TABLE corrections CASCADE;
DROP TABLE events CASCADE;
DROP TABLE files CASCADE;
DROP TABLE filetypes CASCADE;
DROP TABLE properties CASCADE;
DROP TABLE raw_files CASCADE;
DROP TABLE rooms CASCADE;
DROP TABLE speakers CASCADE;
DROP TABLE speakers_talk CASCADEs
DROP TABLE talks CASCADE;
DROP TABLE tracks CASCADE;
DROP TABLE users CASCADE;
EOF

