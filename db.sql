--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.3
-- Dumped by pg_dump version 9.5.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET search_path = public, pg_catalog;

--
-- Name: talkstate; Type: TYPE; Schema: public; Owner: wouter
--

CREATE TYPE talkstate AS ENUM (
    'files_missing',
    'partial_files_found',
    'files_found',
    'generating_previews',
    'preview',
    'review_done',
    'generating_data',
    'waiting',
    'uploading',
    'done',
    'broken'
);


ALTER TYPE talkstate OWNER TO wouter;

--
-- Name: speakerlist(integer); Type: FUNCTION; Schema: public; Owner: wouter
--

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


ALTER FUNCTION public.speakerlist(integer) OWNER TO wouter;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: corrections; Type: TABLE; Schema: public; Owner: wouter
--

CREATE TABLE corrections (
    talk integer NOT NULL,
    property integer NOT NULL,
    property_value character varying
);


ALTER TABLE corrections OWNER TO wouter;

--
-- Name: events; Type: TABLE; Schema: public; Owner: wouter
--

CREATE TABLE events (
    id integer NOT NULL,
    name character varying NOT NULL,
    time_offset integer NOT NULL
);


ALTER TABLE events OWNER TO wouter;

--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: wouter
--

CREATE SEQUENCE events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE events_id_seq OWNER TO wouter;

--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wouter
--

ALTER SEQUENCE events_id_seq OWNED BY events.id;


--
-- Name: files; Type: TABLE; Schema: public; Owner: wouter
--

CREATE TABLE files (
    id integer NOT NULL,
    type integer NOT NULL,
    talk integer NOT NULL,
    "exists" boolean DEFAULT false NOT NULL,
    may_build boolean DEFAULT false NOT NULL
);


ALTER TABLE files OWNER TO wouter;

--
-- Name: files_id_seq; Type: SEQUENCE; Schema: public; Owner: wouter
--

CREATE SEQUENCE files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE files_id_seq OWNER TO wouter;

--
-- Name: files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wouter
--

ALTER SEQUENCE files_id_seq OWNED BY files.id;


--
-- Name: filetypes; Type: TABLE; Schema: public; Owner: wouter
--

CREATE TABLE filetypes (
    id integer NOT NULL,
    description character varying NOT NULL,
    name_template character varying,
    is_source boolean DEFAULT true NOT NULL,
    is_preview boolean DEFAULT false NOT NULL
);


ALTER TABLE filetypes OWNER TO wouter;

--
-- Name: filetypes_id_seq; Type: SEQUENCE; Schema: public; Owner: wouter
--

CREATE SEQUENCE filetypes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE filetypes_id_seq OWNER TO wouter;

--
-- Name: filetypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wouter
--

ALTER SEQUENCE filetypes_id_seq OWNED BY filetypes.id;


--
-- Name: speakers; Type: TABLE; Schema: public; Owner: wouter
--

CREATE TABLE speakers (
    id integer NOT NULL,
    email character varying,
    name character varying NOT NULL
);


ALTER TABLE speakers OWNER TO wouter;

--
-- Name: speakers_talks; Type: TABLE; Schema: public; Owner: wouter
--

CREATE TABLE speakers_talks (
    speaker integer NOT NULL,
    talk integer NOT NULL
);


ALTER TABLE speakers_talks OWNER TO wouter;

--
-- Name: talks; Type: TABLE; Schema: public; Owner: wouter
--

CREATE TABLE talks (
    id integer NOT NULL,
    room integer NOT NULL,
    slug character varying NOT NULL,
    nonce character varying DEFAULT encode(gen_random_bytes(32), 'hex'::text) NOT NULL,
    starttime timestamp with time zone NOT NULL,
    endtime timestamp with time zone NOT NULL,
    title character varying NOT NULL,
    event integer NOT NULL,
    state talkstate DEFAULT 'files_missing'::talkstate NOT NULL,
    comments text
);


ALTER TABLE talks OWNER TO wouter;

--
-- Name: mailers; Type: VIEW; Schema: public; Owner: wouter
--

CREATE VIEW mailers AS
 SELECT speakers.email,
    talks.nonce,
    talks.title
   FROM ((speakers_talks
     JOIN speakers ON ((speakers_talks.speaker = speakers.id)))
     JOIN talks ON ((speakers_talks.talk = talks.id)))
  WHERE (speakers.email IS NOT NULL);


ALTER TABLE mailers OWNER TO wouter;

--
-- Name: properties; Type: TABLE; Schema: public; Owner: wouter
--

CREATE TABLE properties (
    id integer NOT NULL,
    name character varying,
    description character varying
);


ALTER TABLE properties OWNER TO wouter;

--
-- Name: properties_id_seq; Type: SEQUENCE; Schema: public; Owner: wouter
--

CREATE SEQUENCE properties_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE properties_id_seq OWNER TO wouter;

--
-- Name: properties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wouter
--

ALTER SEQUENCE properties_id_seq OWNED BY properties.id;


--
-- Name: rooms; Type: TABLE; Schema: public; Owner: wouter
--

CREATE TABLE rooms (
    id integer NOT NULL,
    name character varying
);


ALTER TABLE rooms OWNER TO wouter;

--
-- Name: rooms_id_seq; Type: SEQUENCE; Schema: public; Owner: wouter
--

CREATE SEQUENCE rooms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE rooms_id_seq OWNER TO wouter;

--
-- Name: rooms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wouter
--

ALTER SEQUENCE rooms_id_seq OWNED BY rooms.id;


--
-- Name: speakers_id_seq; Type: SEQUENCE; Schema: public; Owner: wouter
--

CREATE SEQUENCE speakers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE speakers_id_seq OWNER TO wouter;

--
-- Name: speakers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wouter
--

ALTER SEQUENCE speakers_id_seq OWNED BY speakers.id;


--
-- Name: talk_list; Type: VIEW; Schema: public; Owner: wouter
--

CREATE VIEW talk_list AS
 SELECT talks.id,
    talks.event,
    rooms.name AS room,
    speakerlist(talks.id) AS speakers,
    talks.title AS name,
    talks.nonce,
    talks.slug,
    talks.starttime,
    talks.endtime,
    talks.state,
    talks.comments
   FROM (rooms
     LEFT JOIN talks ON ((rooms.id = talks.room)));


ALTER TABLE talk_list OWNER TO wouter;

--
-- Name: talks_id_seq; Type: SEQUENCE; Schema: public; Owner: wouter
--

CREATE SEQUENCE talks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE talks_id_seq OWNER TO wouter;

--
-- Name: talks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wouter
--

ALTER SEQUENCE talks_id_seq OWNED BY talks.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: wouter
--

CREATE TABLE users (
    id integer NOT NULL,
    email character varying,
    password bytea
);


ALTER TABLE users OWNER TO wouter;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: wouter
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_id_seq OWNER TO wouter;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: wouter
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY events ALTER COLUMN id SET DEFAULT nextval('events_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY files ALTER COLUMN id SET DEFAULT nextval('files_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY filetypes ALTER COLUMN id SET DEFAULT nextval('filetypes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY properties ALTER COLUMN id SET DEFAULT nextval('properties_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY rooms ALTER COLUMN id SET DEFAULT nextval('rooms_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY speakers ALTER COLUMN id SET DEFAULT nextval('speakers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY talks ALTER COLUMN id SET DEFAULT nextval('talks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: corrections_pkey; Type: CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY corrections
    ADD CONSTRAINT corrections_pkey PRIMARY KEY (talk, property);


--
-- Name: events_pkey; Type: CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: files_pkey; Type: CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY files
    ADD CONSTRAINT files_pkey PRIMARY KEY (id);


--
-- Name: filetypes_pkey; Type: CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY filetypes
    ADD CONSTRAINT filetypes_pkey PRIMARY KEY (id);


--
-- Name: properties_pkey; Type: CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY properties
    ADD CONSTRAINT properties_pkey PRIMARY KEY (id);


--
-- Name: rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (id);


--
-- Name: speakers_pkey; Type: CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY speakers
    ADD CONSTRAINT speakers_pkey PRIMARY KEY (id);


--
-- Name: speakers_talks_pkey; Type: CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY speakers_talks
    ADD CONSTRAINT speakers_talks_pkey PRIMARY KEY (speaker, talk);


--
-- Name: talks_nonce_key; Type: CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY talks
    ADD CONSTRAINT talks_nonce_key UNIQUE (nonce);


--
-- Name: talks_pkey; Type: CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY talks
    ADD CONSTRAINT talks_pkey PRIMARY KEY (id);


--
-- Name: talks_slug_key; Type: CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY talks
    ADD CONSTRAINT talks_slug_key UNIQUE (slug);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: corrections_property_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY corrections
    ADD CONSTRAINT corrections_property_fkey FOREIGN KEY (property) REFERENCES properties(id);


--
-- Name: corrections_talk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY corrections
    ADD CONSTRAINT corrections_talk_fkey FOREIGN KEY (talk) REFERENCES talks(id);


--
-- Name: files_talk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY files
    ADD CONSTRAINT files_talk_fkey FOREIGN KEY (talk) REFERENCES talks(id);


--
-- Name: files_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY files
    ADD CONSTRAINT files_type_fkey FOREIGN KEY (type) REFERENCES filetypes(id);


--
-- Name: speakers_talks_speaker_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY speakers_talks
    ADD CONSTRAINT speakers_talks_speaker_fkey FOREIGN KEY (speaker) REFERENCES speakers(id);


--
-- Name: speakers_talks_talk_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY speakers_talks
    ADD CONSTRAINT speakers_talks_talk_fkey FOREIGN KEY (talk) REFERENCES talks(id);


--
-- Name: talks_event_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY talks
    ADD CONSTRAINT talks_event_fkey FOREIGN KEY (event) REFERENCES events(id);


--
-- Name: talks_room_fkey; Type: FK CONSTRAINT; Schema: public; Owner: wouter
--

ALTER TABLE ONLY talks
    ADD CONSTRAINT talks_room_fkey FOREIGN KEY (room) REFERENCES rooms(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

