package SReview::API;

use SReview::Config::Common;

sub init {
	my $app = shift;

	my $config = SReview::Config::Common::setup();

	$app->plugin("OpenAPI" => {
		url => "data:///api.yml",
		schema => "v3",
		security => {
			api_key => sub {
				my ($c, $definition, $scopes, $cb) = @_;
				return $c->$cb('API key not configured') unless defined($config->get('api_key'));
				return $c->$cb('Authorization header not present') unless $c->req->headers->authorization;
				return $c->$cb('API key invalid') unless $c->req->headers->authorization eq $config->get('api_key');
				return $c->$cb();
			},
			sreview_auth => sub {
				my ($c, $definition, $scopes, $cb) = @_;
				return $c->$cb('OAuth2 not yet implemented');
			},
		}
	});
}

1;

__DATA__
@@ api.yml
openapi: 3.0.1
info:
  title: SReview API
  description: SReview is an AGPLv3 video review tool.
  contact:
    email: w@uter.be
  license:
    name: AGPLv3
    url: https://www.gnu.org/licenses/agpl-3.0.en.html
  version: 1.0.0
externalDocs:
  description: Find out more about SReview
  url: https://yoe.github.io/sreview
servers:
- url: https://sreview.example.com/api/v1
tags:
- name: event
  description: Managing events
- name: talk
  description: Managing talks
- name: speaker
  description: Managing speakers
- name: room
  description: Managing rooms
- name: track
  description: Managing tracks
- name: user
  description: Managing users
paths:
  /event:
    post:
      tags:
      - event
      summary: Add a new event
      operationId: add_event
      requestBody:
        description: Event object that needs to be added to the store
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Event'
        required: true
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Event"
      security:
      - api_key: []
      x-mojo-to:
        controller: event
        action: add
  /event/{eventId}:
    patch:
      tags:
      - event
      summary: Update an existing event
      operationId: update_event
      parameters:
      - name: eventId
        in: path
        required: true
        schema:
          $ref: '#/components/schemas/Event/properties/id'
      requestBody:
        description: Event object that needs to be modified in the store
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Event'
        required: true
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Event"
        404:
          description: Event not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: event
        action: update
    get:
      tags:
      - event
      summary: Find event by ID
      description: Returns a single event
      operationId: get_event
      parameters:
      - name: eventId
        in: path
        description: ID of event to return
        required: true
        schema:
          type: integer
          format: int64
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Event'
        400:
          description: Invalid ID supplied
          content: {}
        404:
          description: Event not found
          content: {}
      x-mojo-to:
        controller: event
        action: getById
    delete:
      tags:
      - event
      summary: Delete an event
      operationId: delete_event
      parameters:
      - name: eventId
        in: path
        description: Event id to delete
        required: true
        schema:
          type: integer
          format: int64
      responses:
        200:
          description: Successful operation
          content:
            application/json:
              schema:
                type: integer
                format: int64
        404:
          description: Event not found
          content: {}
        405:
          description: Event not empty
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: event
        action: delete
  /event/list:
    get:
      tags:
      - event
      summary: Return a list of events
      operationId: event_list
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Event'
      x-mojo-to:
        controller: event
        action: list
  /event/{eventId}/talk:
    post:
      tags:
      - talk
      summary: Add a new talk
      operationId: add_talk
      parameters:
      - name: eventId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Talk'
        required: false
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Talk'
        404:
          description: Event not found
          content: {}
        405:
          description: Invalid input
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: talk
        action: add
  /event/{eventId}/talk/{talkId}:
    patch:
      tags:
      - talk
      summary: Update an existing talk
      operationId: update_talk
      parameters:
      - name: eventId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      - name: talkId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Talk'
        required: false
      responses:
        200:
          description: successful operation
          content: 
            application/json:
              schema:
                $ref: "#/components/schemas/Talk"
        400:
          description: Invalid input
          content: {}
        404:
          description: Event or talk not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: talk
        action: update
    delete:
      tags:
      - talk
      summary: Delete a talk
      operationId: delete_talk
      parameters:
      - name: eventId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      - name: talkId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      responses:
        200:
          description: Successful operation
          content: {}
        404:
          description: Event or talk not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: talk
        action: delete
    get:
      tags:
      - talk
      summary: Get a talk by ID
      operationId: get_talk
      parameters:
      - name: eventId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      - name: talkId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Talk'
        404:
          description: Event or talk not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: talk
        action: getById
  /event/{eventId}/talk/{talkId}/corrections:
    get:
      tags:
      - talk
      summary: Get the corrections for the talk
      operationId: talk_corrections
      parameters:
      - name: eventId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      - name: talkId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/TalkCorrections'
        404:
          description: Event or talk not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: talk
        action: getCorrections
    patch:
      tags:
      - talk
      summary: Set the corrections for the talk
      operationId: set_corrections
      parameters:
      - name: eventId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      - name: talkId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TalkCorrections'
        required: false
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/TalkCorrections'
        404:
          description: Event or talk not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: talk
        action: setCorrections
  /event/{eventId}/talk/list:
    get:
      tags:
      - talk
      summary: Get a list of talks for the event
      operationId: talk_list
      parameters:
      - name: eventId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Talk'
        404:
          description: Event not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: talk
        action: listByEvent
  /event/{eventId}/talk/{talkId}/speakers:
    get:
      tags:
      - speaker
      summary: Get the list of speakers for a talk
      operationId: get_talk_speakers
      parameters:
      - name: eventId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      - name: talkId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Speaker'
        404:
          description: event or talk not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: speaker
        action: listByTalk
    put:
      tags:
      - speaker
      summary: Replace the list of speakers for a given talk
      operationId: replace_speakers
      parameters:
      - name: eventId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      - name: talkId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      requestBody:
        content:
          application/json:
            schema:
              type: array
              items:
                $ref: '#/components/schemas/Speaker/properties/id'
        required: false
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Speaker/properties/id'
        404:
          description: event, talk, or speakers not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: talk
        action: setSpeakers
    post:
      tags:
      - speaker
      summary: Add speakers to the given talk
      operationId: add_speakers
      parameters:
      - name: eventId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      - name: talkId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      requestBody:
        content:
          application/json:
            schema:
              type: array
              items:
                $ref: '#/components/schemas/Speaker/properties/id'
        required: false
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Speaker/properties/id'
        404:
          description: event, talk, or speakers not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: talk
        action: addSpeakers
  /nonce/{nonce}/data:
    get:
      tags:
      - talk
      summary: Retrieve talk data by nonce
      operationId: get_nonce_data
      parameters:
      - name: nonce
        in: path
        required: true
        schema:
          type: string
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/TalkData'
        404:
          description: talk not found
          content: {}
      x-mojo-to:
        controller: review
        action: data
  /nonce/{nonce}/talk:
    get:
      tags:
      - talk
      summary: Retrieve talk object by nonce
      operationId: get_nonce_talk
      parameters:
      - name: nonce
        in: path
        required: true
        schema:
          type: string
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Talk'
        404:
          description: talk not found
          content: {}
      x-mojo-to:
        controller: talk
        action: getByNonce
  /nonce/{nonce}/talk/corrections:
    get:
      tags:
      - talk
      summary: Retrieve talk corrections by nonce
      operationId: get_nonce_corrections
      parameters:
      - name: nonce
        in: path
        required: true
        schema:
          type: string
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/TalkCorrections'
        404:
          description: talk not found
          content: {}
        x-mojo-to:
          controller: talk
          action: getCorrections
    patch:
      tags:
      - talk
      summary: Set talk corrections by nonce
      operationId: set_nonce_corrections
      parameters:
      - name: nonce
        in: path
        required: true
        schema:
          type: string
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/TalkCorrections'
        404:
          description: talk not found
          content: {}
      x-mojo-to:
        controller: talk
        action: getCorrections;
  /speaker/search/{searchString}:
    get:
      tags:
      - speaker
      summary: Find speakers based on a substring of their name or email address
      operationId: find_speaker
      parameters:
      - name: searchString
        in: path
        required: true
        schema:
          type: string
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Speaker'
        404:
          description: speaker not found
          content: {}
      x-mojo-to:
        controller: speaker
        action: search
      security:
      - api_key: []
  /speaker:
    post:
      tags:
      - speaker
      summary: Add a new speaker to the system
      operationId: add_speaker
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Speaker'
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Speaker'
      security:
      - api_key: []
      x-mojo-to:
        controller: speaker
        action: add
  /speaker/{speakerId}:
    patch:
      tags:
      - speaker
      summary: Update an existing speaker
      operationId: update_speaker
      parameters:
      - name: speakerId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Speaker'
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Speaker'
        404:
          description: speaker not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: speaker
        action: update
    get:
      tags:
      - speaker
      summary: Get a speaker
      operationId: get_speaker
      parameters:
      - name: speakerId
        in: path
        required: true
        schema:
          $ref: '#/components/schemas/Speaker/properties/id'
      responses:
        200:
          description: successful operation
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Speaker'
        404:
          description: Speaker not found
          content: {}
      x-mojo-to:
        controller: speaker
        action: getById
      security:
      - api_key: []
    delete:
      tags:
      - speaker
      summary: Remove a speaker from the system
      operationId: delete_speaker
      parameters:
      - name: speakerId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      responses:
        200:
          description: successful operation
          content: {}
        404:
          description: speaker not found
          content: {}
      security:
      - api_key: []
  /room:
    post:
      tags:
      - room
      summary: Add a room
      operationId: add_room
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Room'
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Room'
      security:
      - api_key: []
      x-mojo-to:
        controller: room
        action: add
  /room/{roomId}:
    patch:
      tags:
      - room
      summary: Update a room
      operationId: update_room
      parameters:
      - name: roomId
        in: path
        required: true
        schema:
          type: integer
          format: int64
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Room'
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Room'
        404:
          description: Room not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: room
        action: update
    get:
      tags:
      - room
      summary: Retrieve a room's details
      operationId: get_room
      parameters:
      - name: roomId
        in: path
        required: true
        schema:
          $ref: '#/components/schemas/Room/properties/id'
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Room'
        404:
          description: Room not found
          content: {}
      x-mojo-to:
        controller: room
        action: getById
    delete:
      tags:
      - room
      summary: Remove a room
      operationId: delete_room
      parameters:
      - name: roomId
        in: path
        required: true
        schema:
          $ref: '#/components/schemas/Room/properties/id'
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                type: integer
                format: int64
        404:
          description: Room not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: room
        action: delete
  /room/list:
    get:
      tags:
      - room
      summary: Retrieve the list of rooms
      operationId: room_list
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Room'
      x-mojo-to:
        controller: room
        action: list
  /track:
    post:
      tags:
      - track
      summary: Add a track
      operationId: add_track
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Track'
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Track'
      security:
      - api_key: []
      x-mojo-to:
        controller: track
        action: add
  /track/list:
    get:
      tags:
      - track
      summary: Retrieve the list of tracks
      operationId: track_list
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Track'
      x-mojo-to:
        controller: track
        action: list
  /track/{trackId}:
    patch:
      tags:
      - track
      summary: Update a track
      operationId: update_track
      parameters:
      - name: trackId
        in: path
        required: true
        schema:
          $ref: '#/components/schemas/Track/properties/id'
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Track'
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Track'
        404:
          description: Track not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: track
        action: update
    get:
      tags:
      - track
      summary: Retrieve a track by ID
      operationId: get_track
      parameters:
      - name: trackId
        in: path
        required: true
        schema:
          $ref: '#/components/schemas/Track/properties/id'
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Track'
        400:
          description: Track not found
          content: {}
      x-mojo-to:
        controller: track
        action: getById
    delete:
      tags:
      - track
      summary: Delete a track
      operationId: delete_track
      parameters:
      - name: trackId
        in: path
        required: true
        schema:
          $ref: '#/components/schemas/Track/properties/id'
      responses:
        200:
          description: OK
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: track
        action: delete
  /user:
    post:
      tags:
      - user
      summary: Add a user
      operationId: add_user
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/User'
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
      security:
      - api_key: []
      x-mojo-to:
        controller: user
        action: add
  /user/{userId}:
    patch:
      tags:
      - user
      summary: Update a user
      operationId: update_user
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/User'
      parameters:
      - name: userId
        in: path
        required: true
        schema:
          $ref: '#/components/schemas/User/properties/id'
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        404:
          description: User not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: user
        action: update
    get:
      tags:
      - user
      summary: Retrieve a user's details
      operationId: get_user
      parameters:
      - name: userId
        in: path
        required: true
        schema:
          $ref: '#/components/schemas/User/properties/id'
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        404:
          description: User not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: user
        action: getById
    delete:
      tags:
      - user
      summary: Delete a user
      operationId: delete_user
      parameters:
      - name: userId
        in: path
        required: true
        schema:
          $ref: '#/components/schemas/User/properties/id'
      responses:
        200:
          description: OK
          content: {}
        404:
          description: User not found
          content: {}
      security:
      - api_key: []
      x-mojo-to:
        controller: user
        action: delete
  /user/list:
    get:
      tags:
      - user
      summary: Retrieve the list of all users
      operationId: user_list
      responses:
        200:
          description: OK
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/User'
      security:
      - api_key: []
      x-mojo-to:
        controller: user
        action: list
components:
  schemas:
    Talk:
      type: object
      properties:
        id:
          type: integer
          format: int64
          description: ID of the talk
        room:
          $ref: '#/components/schemas/Room/properties/id'
        event:
          $ref: '#/components/schemas/Event/properties/id'
        nonce:
          type: string
          description: nonce (URL part to be handed out to unauthenticated reviewers) of this talk
        slug:
          type: string
          description: unique part of the string, will be used for (part of) the output name
        starttime:
          type: string
          format: date-time
          description: time this talk will (have) start(ed)
        endtime:
          type: string
          format: date-time
          description: time this talk will (have) end(ed)
        title:
          type: string
          description: title of this talk
        subtitle:
          type: string
          nullable: true
          description: subtitle of this talk, if any
        state:
          type: string
          default: waiting_for_files
          description: current state of the talk
          enum:
          - waiting_for_files
          - cutting
          - generating_previews
          - notification
          - preview
          - transcoding
          - uploading
          - announcing
          - done
          - injecting
          - broken
          - needs_work
          - lost
          - ignored
        progress:
          type: string
          default: waiting
          description: how far along the talk is in the current state
          enum:
          - waiting
          - scheduled
          - running
          - done
          - failed
        prelen:
          type: string
          format: time
          description: length of the 'pre' video of this talk, if any
          nullable: true
        postlen:
          type: string
          format: time
          description: length of the 'post' video of this talk, if any
          nullable: true
        track:
          type: integer
          format: int64
          nullable: true
          description: Track this talk is being held in, if any
        reviewer:
          type: integer
          format: int64
          nullable: true
          description: Reviewer who last touched this talk, if known
        perc:
          type: integer
          format: int32
          nullable: true
          description: percentage completion of the current state
        apologynote:
          type: string
          nullable: true
          description: apology note for technical issues, if any
        description:
          type: string
          nullable: true
          description: long-form description of this talk
        active_stream:
          type: string
          default: ""
          description: stream of this talk that is currently active
        upstreamid:
          type: string
        flags:
          type: string
          description: string-encoded JSON object of flags on this talk, if any
          example: '{"is_injected":false}'
    Event:
      type: object
      properties:
        id:
          type: integer
          format: int64
        name:
          type: string
        inputdir:
          type: string
          nullable: true
        outputdir:
          type: string
          nullable: true
    Room:
      type: object
      properties:
        id:
          type: integer
          format: int64
        name:
          type: string
        altname:
          type: string
          nullable: true
        outputname:
          type: string
          nullable: true
    Track:
      type: object
      properties:
        id:
          type: integer
          format: int64
        name:
          type: string
        email:
          type: string
          format: email
        upstreamid:
          type: string
    User:
      type: object
      properties:
        id:
          type: integer
          format: int64
        name:
          type: string
        email:
          type: string
          format: email
        isAdmin:
          type: boolean
        isVolunteer:
          type: boolean
        limitToRoom:
          $ref: '#/components/schemas/Room/properties/id'
    Speaker:
      type: object
      properties:
        id:
          type: integer
          format: int64
        email:
          type: string
          format: email
          nullable: true
        name:
          type: string
        upstreamid:
          type: string
          nullable: true
    TalkData:
      type: object
      properties:
        start:
          type: string
          format: date-time
        end:
          type: string
          format: date-time
        start_iso:
          type: string
          format: date-time
        end_iso:
          type: string
          format: date-time
    TalkCorrections:
      type: object
      properties:
        offset_audio:
          type: string
        audio_channel:
          type: string
        length_adj:
          type: string
        offset_start:
          type: string
        serial:
          type: string
  securitySchemes:
    api_key:
      type: apiKey
      name: Authorization
      in: header
