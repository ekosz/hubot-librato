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
#   hubot graph me <instrument> [over the last <time period>] - Get graph from
#     librato
#
# Author:
#   Eric Koslow


parseTimePeriod= (time) ->
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

getGraphForIntrument = (inst, msg, time_period, robot) ->
  timePeriodInSeconds = parseTimePeriod(time_period)

  unless timePeriodInSeconds
    msg.reply "Sorry, I couldn't understand the time period #{time_period}. \nTry something like '[<number> ]<second|minute|hour|day|week>s'"
    return

  url = "https://metrics.librato.com/snap_shot?instrument_id=#{inst['id']}"
  formData = "instrument_id=#{inst['id']}&duration=#{timePeriodInSeconds}"

  createSnapshot(url, formData, msg, robot)

processIntrumentResponse = (res, msg, time_period, robot) ->
  json = JSON.parse(res.body)
  found = json['query']['found']
  if found == 0
    msg.reply "Sorry, couldn't find that graph!"
  else if found > 1
    names = json['query']['instruments'].reduce (acc, inst) -> acc + "\n" + inst['name']
    msg.reply "I found #{found} graphs named something like that. Which one did you mean?\n\n#{names}"
  else
    getGraphForIntrument(json['query']['instruments'][0], msg, time_period, robot)

module.exports = (robot) ->
  robot.respond /graph me ([\w ]+)$/i, (msg) ->
    instrument = time_period = msg.match[1].split('over the last')

    time_period ||= 'hour'

    user = process.env.HUBOT_LIBRATO_USER
    pass = process.env.HUBOT_LIBRATO_TOKEN
    auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64')

    robot.http("https://metrics.librato.com/metrics-api/v1/instruments&name=#{instrument}")
      .headers(Authorization: auth, Accept: 'application/json')
      .get() (err, res, body) ->
        switch res.statusCode
          when 200
            processIntrumentResponse(res, msg, time_period, robot)
          else
            msg.reply "Unable to get list of instruments from librato :(\nStatus Code: #{res.statusCode}\nBody:\n\n#{res.body}"
