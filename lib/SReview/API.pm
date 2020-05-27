package SReview::API;

sub init {
	my $app = shift;

	$app->plugin("OpenAPI" => { url => "data:///api.yml", schema => "v3" });
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
paths:
  /event:
    put:
      tags:
      - event
      summary: Update an existing event
      operationId: update_event
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
        400:
          description: Invalid ID supplied
          content: {}
        404:
          description: Event not found
          content: {}
        405:
          description: Validation exception
          content: {}
      security:
      - sreview_auth:
        - write:events
        - read:events
      x-mojo-to:
        controller: event
        action: update
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
                $ref: "#/components/schemas/Event/properties/id"
        405:
          description: Invalid input
          content: {}
      security:
      - sreview_auth:
        - write:events
        - read:events
      x-mojo-to:
        controller: event
        action: add
  /event/{eventId}:
    get:
      tags:
      - event
      summary: Find event by ID
      description: Returns a single event
      operationId: get_pet_by_id
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
    post:
      tags:
      - event
      summary: Update an event with form data
      operationId: update_event_with_form
      parameters:
      - name: eventId
        in: path
        description: ID of event that needs to be updated
        required: true
        schema:
          type: integer
          format: int64
      requestBody:
        content:
          application/x-www-form-urlencoded:
            schema:
              properties:
                name:
                  type: string
                  description: Updated name of the event
                inputdir:
                  type: string
                  description: Updated input directory of the event
                outputdir:
                  type: string
                  description: Updated output directory of the event
      responses:
        404:
          description: Event not found
          content: {}
        405:
          description: Invalid input
          content: {}
      security:
      - sreview_auth:
        - write:events
        - read:events
      x-mojo-to:
        controller: event
        action: updateForm
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
        400:
          description: Invalid ID supplied
          content: {}
        404:
          description: Event not found
          content: {}
        405:
          description: Event not empty
          content: {}
      security:
      - sreview_auth:
        - write:events
        - read:events
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
    put:
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
      - sreview_auth:
        - write:talks
      x-mojo-to:
        controller: talk
        action: update
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
                type: integer
                format: int64
        404:
          description: Event not found
          content: {}
        405:
          description: Invalid input
          content: {}
      security:
      - sreview_auth:
        - write:talks
      x-mojo-to:
        controller: talk
        action: add
      x-codegen-request-body-name: body
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
      responses:
        200:
          description: Successful operation
          content: {}
        404:
          description: Event or talk not found
          content: {}
        405:
          description: Invalid input
          content: {}
      security:
      - sreview_auth:
        - write:talks
      x-mojo-to:
        controller: talk
        action: delete
  /event/{eventId}/talk/{talkId}:
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
        405:
          description: invalid input
          content: {}
      security:
      - sreview_auth:
        - read:talks
      x-mojo-to:
        controller: talk
        action: getById
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
      - sreview_auth:
        - read:talks
      x-mojo-to:
        controller: talk
        action: listByEvent
  /event/{eventId}/talk/{talkId}/speakers:
    get:
      tags:
      - speaker
      summary: Get the list of speakers for a talk
      operationId: get_speakers
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
          content: {}
        404:
          description: event or talk not found
          content: {}
        405:
          description: invalid input
          content: {}
      security:
      - sreview_auth:
        - write:talks
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
            '*/*':
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Speaker/properties/id'
        404:
          description: event or talk not found
          content: {}
        405:
          description: invalid input
          content: {}
      security:
      - sreview_auth:
        - write:talks
      x-codegen-request-body-name: body
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
          description: event or talk not found
          content: {}
        405:
          description: invalid input
          content: {}
      security:
      - sreview_auth:
        - write:talks
      x-codegen-request-body-name: body
components:
  schemas:
    Talk:
      type: object
      properties:
        id:
          type: integer
          format: int64
        room:
          $ref: '#/components/schemas/Room/properties/id'
        event:
          $ref: '#/components/schemas/Event/properties/id'
        nonce:
          type: string
        slug:
          type: string
        starttime:
          type: string
          format: date-time
        endtime:
          type: string
          format: date-time
        title:
          type: string
        subtitle:
          type: string
          nullable: true
        state:
          type: string
          default: waiting_for_files
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
          - broken
          - needs_work
          - lost
          - ignored
        progress:
          type: string
          default: waiting
          enum:
          - waiting
          - scheduled
          - running
          - done
          - failed
        prelen:
          type: string
          format: interval
          nullable: true
        postlen:
          type: string
          format: interval
          nullable: true
        track:
          type: integer
          format: int64
          nullable: true
        reviewer:
          type: integer
          format: int64
          nullable: true
        perc:
          type: integer
          format: int32
          nullable: true
        apologynote:
          type: string
          nullable: true
        description:
          type: string
          nullable: true
        active_stream:
          type: string
          default: ""
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
        outputname:
          type: string
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
        name:
          type: string
        upstreamid:
          type: string
  securitySchemes:
    sreview_auth:
      type: oauth2
      flows:
        implicit:
          authorizationUrl: https://sreview.example.com/oauth/dialog
          scopes:
            write:events: modify events
            read:events: read events
            write:talks: modify talks
            read:talks: read talks with full detail
    api_key:
      type: apiKey
      name: api_key
      in: header
