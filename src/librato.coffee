# Description:
#   Pulls graphs from Librato
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_LIBRATO_USER
#   HUBOT_LIBRATO_TOKEN
#
# Commands:
#   hubot graph me <instrument> [over the last <time peroid>] - Get graph from
#     librato
#
# Author:
#   Eric Koslow


parseTimePeriod = (time) ->
  matchData = /(\d+)?\s*(second|minute|hour|day|week)s?/.exec(time)
  return unless matchData[2]

  amount = if matchData[1] then parseInt(matchData, 10) else 1
  return amount * switch matchData[2]
    when 'second'
      1
    when 'minute'
      60
    when 'hour'
      60 * 60
    when 'day'
      60 * 60 * 24
    when 'week'
      60 * 60 * 24 * 7

getSnapshot = (url, msg, robot) ->
  user = process.env.HUBOT_LIBRATO_USER
  pass = process.env.HUBOT_LIBRATO_TOKEN
  auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64')
  robot.http(url)
    .headers(Authorization: auth, Accept: 'application/json')
    .get() (err, res, body) ->
      switch res.statusCode
        when 200
          json = JSON.parse(body)
          if json['image_href']
            msg.reply json['image_href']
          else
            setTimeout ( ->
              getSnapshot(url, msg, robot)
            ), 100
        when 204
          setTimeout ( ->
            getSnapshot(url, msg, robot)
          ), 100
        else
          msg.reply "Unable to get snap shot from librato :(\nStatus Code: #{res.statusCode}\nBody:\n\n#{body}"

createSnapshot = (inst, time, msg, robot) ->
  url = "https://metrics-api.librato.com/v1/snapshots"
  data = JSON.stringify({
    subject: {
      instrument: {
        href: "https://metrics-api.librato.com/v1/instruments/#{inst.id}"
      }
    },
    duration: time,
  })
  user = process.env.HUBOT_LIBRATO_USER
  pass = process.env.HUBOT_LIBRATO_TOKEN
  auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64')

  robot.http(url)
    .headers(Authorization: auth, Accept: 'application/json', 'Content-Type': 'application/json')
    .post(data) (err, res, body) ->
      switch res.statusCode
        when 201
          json = JSON.parse(body)
          msg.reply json['image_href']
        when 202
          json = JSON.parse(body)
          getSnapshot(json['href'], msg, robot)
        else
          msg.reply "Unable to create snap shot from librato :(\nStatus Code: #{res.statusCode}\nBody:\n\n#{body}"

getGraphForIntrument = (inst, msg, timePeriod, robot) ->
  timePeriodInSeconds = parseTimePeriod(timePeriod)

  unless timePeriodInSeconds
    msg.reply "Sorry, I couldn't understand the time peroid #{timePeriod}.\nTry something like '[<number> ]<second|minute|hour|day|week>s'"
    return

  createSnapshot(inst, timePeriodInSeconds, msg, robot)

processIntrumentResponse = (body, msg, timePeriod, robot) ->
  json = JSON.parse(body)
  found = json['query']['found']
  if found == 0
    msg.reply "Sorry, couldn't find that graph!"
  else if found > 1
    names = json['query']['instruments'].reduce (acc, inst) -> acc + "\n" + inst.name
    msg.reply "I found #{found} graphs named something like that. Which one did you mean?\n\n#{names}"
  else
    getGraphForIntrument(json['instruments'][0], msg, timePeriod, robot)

module.exports = (robot) ->
  robot.respond /graph me ([\w ]+?)\s*(?:over the (?:last|past)? )?(\d+ (?:second|minute|hour|day|week)s?)?$/i, (msg) ->
    instrument = msg.match[1]
    timePeriod = msg.match[2] || 'hour'

    user = process.env.HUBOT_LIBRATO_USER
    pass = process.env.HUBOT_LIBRATO_TOKEN
    auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64')

    robot.http("https://metrics-api.librato.com/v1/instruments?name=#{escape(instrument)}")
      .headers(Authorization: auth, Accept: 'application/json')
      .get() (err, res, body) ->
        switch res.statusCode
          when 200
            processIntrumentResponse(body, msg, timePeriod, robot)
          else
            msg.reply "Unable to get list of instruments from librato :(\nStatus Code: #{res.statusCode}\nBody:\n\n#{body}"
