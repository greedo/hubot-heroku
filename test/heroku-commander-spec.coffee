HubotHelper = require('hubot-test-helper')
path = require('path')
chai = require("chai")
nock = require("nock")
process.env.HUBOT_HEROKU_API_KEY = 'fake_key'

{ expect } = chai

describe "HerokuCommander", ->

  helper = new HubotHelper("../index.coffee")
  room = null
  mockHeroku = nock("https://api.heroku.com")
  duration = 3

  beforeEach ->
    room = helper.createRoom()

  it "exposes help commands", ->
    commands = room.robot.commands

    expect(commands).to.have.length(6)

    expect(commands).to.include("hubot heroku releases <app> - Latest 10 releases")
    expect(commands).to.include("hubot heroku rollback <app> <version> - Rollback to a release")
    expect(commands).to.include("hubot heroku restart <app> - Restarts the app")
    expect(commands).to.include("hubot heroku migrate <app> - Runs migrations. Remember to restart the app =)")
    expect(commands).to.include("hubot heroku config:set <app> <KEY=value> - Set KEY to value. Overrides present key")
    expect(commands).to.include("hubot heroku config:unset <app> <KEY> - Unsets KEY, does not throw error if key is not present")

  describe "heroku releases <app>", ->
    it "gets the 10 recent releases", (done) ->
      mockHeroku
        .get("/apps/shield-global-watch/releases")
        .replyWithFile(200, __dirname + "/fixtures/releases.json")

      room.user.say "Damon", "hubot heroku releases shield-global-watch"

      setTimeout(->
        expect(room.messages[1][1]).to.equal("@Damon Getting releases for shield-global-watch")
        expect(room.messages[2][1]).to.include("@Damon Recent releases of shield-global-watch\nv352 - Promote shield-global-watch v287 fb2b5ff - phil@shield.com")
        done()
      , duration)


  describe "heroku rollback <app> <version>", ->
    beforeEach ->
      mockHeroku
        .get("/apps/shield-global-watch/releases")
        .replyWithFile(200, __dirname + "/fixtures/releases.json")

      mockHeroku
        .post('/apps/shield-global-watch/releases')
        .replyWithFile(200,  __dirname + "/fixtures/rollback.json",)

    it "rolls back the app to the specified version", (done) ->
      room.user.say "Damon", "hubot heroku rollback shield-global-watch v352"

      setTimeout(->
        expect(room.messages[1][1]).to.equal("@Damon Telling Heroku to rollback to v352")
        expect(room.messages[2][1]).to.equal("@Damon Success! v353 -> Rollback to v352")
        done()
      , duration)

    it "tells the user about a bad version", (done) ->
      room.user.say "Damon", "hubot heroku rollback shield-global-watch v999"

      setTimeout(->
        expect(room.messages[1][1]).to.equal("@Damon Telling Heroku to rollback to v999")
        expect(room.messages[2][1]).to.equal("@Damon Version v999 not found for shield-global-watch :(")
        done()
      , duration)

  describe "heroku restart <app>", ->
    it "restarts the app", (done) ->
      mockHeroku
        .delete("/apps/shield-global-watch/dynos")
        .reply(200, {})

      room.user.say "Damon", "hubot heroku restart shield-global-watch"

      setTimeout(->
        expect(room.messages[1][1]).to.equal("@Damon Telling Heroku to restart shield-global-watch")
        expect(room.messages[2][1]).to.equal("@Damon Heroku: Restarting shield-global-watch")
        done()
      , duration)

  describe "heroku migrate <app>", ->
    it "runs migrations", (done) ->
      mockHeroku
        .post("/apps/shield-global-watch/dynos",
          command: "rake db:migrate"
          attach: true
          size: "1X"
        ).replyWithFile(200, __dirname + "/fixtures/migrate.json")

      room.user.say "Damon", "hubot heroku migrate shield-global-watch"

      setTimeout(->
        expect(room.messages[1][1]).to.equal("@Damon Telling Heroku to migrate shield-global-watch")
        expect(room.messages[2][1]).to.equal("@Damon Heroku: Running migrations for shield-global-watch")
        done()
      , duration)

  describe "heroku config:set", ->
    it "sets config <KEY=value>", (done) ->
      mockHeroku
        .patch("/apps/shield-global-watch/config-vars",
          "CLOAK_ID": 10
        ).replyWithFile(200, __dirname + "/fixtures/config-set.json")

      room.user.say "Damon", "hubot heroku config:set shield-global-watch CLOAK_ID=10"

      setTimeout(->
        expect(room.messages[1][1]).to.equal("@Damon Setting config CLOAK_ID => 10")
        expect(room.messages[2][1]).to.equal("@Damon Heroku: CLOAK_ID is set to 10")
        done()
      , duration)

  describe "heroku config:unset <KEY>", ->
    it "unsets config <KEY>", (done) ->
      mockHeroku
        .patch("/apps/shield-global-watch/config-vars",
          "CLOAK_ID": null
        ).reply(200, {})

      room.user.say "Damon", "hubot heroku config:unset shield-global-watch CLOAK_ID"

      setTimeout(->
        expect(room.messages[1][1]).to.equal("@Damon Unsetting config CLOAK_ID")
        expect(room.messages[2][1]).to.equal("@Damon Heroku: CLOAK_ID has been unset")
        done()
      , duration)
