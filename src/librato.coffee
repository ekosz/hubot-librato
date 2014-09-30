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


parseTimePeroid = (time) ->
  matchData = /(\d+)?\s*(second|minute|hour|day|week)s?/.exec(time)
  return unless matchData[2]

  amount = matchData[1] ? parseInt(matchData, 10) : 1
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
  responseHandler = (err, res, body) ->
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
        msg.reply "Unable to snap shot from librato :(\nStatus Code: #{res.statusCode}\nBody:\n\n#{res.body}"

  user = process.env.HUBOT_LIBRATO_USER
  pass = process.env.HUBOT_LIBRATO_TOKEN
  auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64')
  robot.http(url)
    .headers(Authorization: auth, Accept: 'application/json')
    .get(responseHandler)

createSnapshot = (url, formData, msg, robot) ->
  user = process.env.HUBOT_LIBRATO_USER
  pass = process.env.HUBOT_LIBRATO_TOKEN
  auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64')

  robot.http(url)
    .headers(Authorization: auth, Accept: 'application/json')
    .post(formData) (err, res, body) ->
      if err
        msg.reply "Unable to create snap shot from librato :(\nStatus Code: #{res.statusCode}\nBody:\n\n#{res.body}"
      else
        json = JSON.parse(body)
        getSnapshot(json['uri'])

getGraphForIntrument = (inst, msg, time_peroid, robot) ->
  timePeroidInSeconds = parseTimePeroid(time_peroid)

  unless timePeroidInSeconds
    msg.reply "Sorry, I couldn't understand the time peroid #{time_peroid}. \nTry something like '[<number> ]<second|minute|hour|day|week>s'"
    return

  url = "https://metrics.librato.com/snap_shot?instrument_id=#{inst['id']}"
  formData = "instrument_id=#{inst['id']}&duration=#{timePeroidInSeconds}"

  createSnapshot(url, formData, msg, robot)

processIntrumentResponse = (res, msg, time_peroid, robot) ->
  json = JSON.parse(res.body)
  found = json['query']['found']
  if found == 0
    msg.reply "Sorry, couldn't find that graph!"
  else if found > 1
    names = json['query']['instruments'].reduce (acc, inst) -> acc + "\n" + inst['name']
    msg.reply "I found #{found} graphs named something like that. Which one did you mean?\n\n#{names}"
  else
    getGraphForIntrument(json['query']['instruments'][0], msg, time_peroid, robot)

module.exports = (robot) ->
  robot.respond /graph me ([\w ]+)$/i, (msg) ->
    instrement, time_peroid = msg.match[1].split('over the last')
    time_peroid ||= 'hour'

    user = process.env.HUBOT_LIBRATO_USER
    pass = process.env.HUBOT_LIBRATO_TOKEN
    auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64')

    robot.http("https://metrics.librato.com/metrics-api/v1/instruments&name=#{instrument}")
      .headers(Authorization: auth, Accept: 'application/json')
      get() (err, res, body) ->
        switch res.statusCode
          when 200
            processIntrumentResponse(res, msg, time_peroid, robot)
          else
            msg.reply "Unable to get list of instruments from librato :(\nStatus Code: #{res.statusCode}\nBody:\n\n#{res.body}"
