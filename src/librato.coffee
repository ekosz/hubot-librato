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
#   hubot graph spaces
#   - Get a list of possible spaces
#   hubot graphs <space>
#   - Get a list of possible graphs for a specific space
#   hubot graph me <space>/<chart> [over the last <time period>] [source <source>] [type line|stacked|bignumber]
#   - Get graph from Librato
#
# Author:
#   Eric Koslow
#   Jason Dixon


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

getSpaces = (auth, robot, msg) ->
  url = "https://metrics-api.librato.com/v1/spaces"
  robot.http(url)
      .headers(Authorization: auth, Accept: 'application/json')
      .get() (err, res, body) ->
        switch res.statusCode
          when 200
            printSpaces(msg, JSON.parse(body))
          else
            msg.reply "Unable to get list of spaces from librato :(\nStatus Code: #{res.statusCode}\nBody:\n\n#{body}"

getChartsForSpace = (auth, robot, msg, space) ->
  url = "https://metrics-api.librato.com/v1/spaces?name=#{escape(space)}"
  robot.http(url)
      .headers(Authorization: auth, Accept: 'application/json')
      .get() (err, res, body) ->
        switch res.statusCode
          when 200
            json = JSON.parse(body)
            found = json['query']['found']
            if found == 0
              msg.reply "Sorry, couldn't find any spaces by name #{name}"
            else
              id = json['spaces'][0]['id']
              getAllChartsForSpace(auth, robot, msg, id)
          else
            msg.reply "Unable to get list of spaces from librato :(\nStatus Code: #{res.statusCode}\nBody:\n\n#{body}"

getAllChartsForSpace = (auth, robot, msg, space) ->
  url = "https://metrics-api.librato.com/v1/spaces/#{escape(space)}/charts"
  robot.http(url)
      .headers(Authorization: auth, Accept: 'application/json')
      .get() (err, res, body) ->
        switch res.statusCode
          when 200
            printCharts(msg, JSON.parse(body))
          else
            msg.reply "Unable to get list of charts for space #{spaceId} from librato :(\nStatus Code: #{res.statusCode}\nBody:\n\n#{body}"

getSnapshot = (auth, robot, msg, space, chart, source, type, timePeriod) ->
  url = "https://metrics-api.librato.com/v1/spaces"
  robot.http(url)
      .headers(Authorization: auth, Accept: 'application/json')
      .get() (err, res, body) ->
        switch res.statusCode
          when 200
            json = JSON.parse(body)
            s = findByName(space, json['spaces'])
            if space
              getChartForSpace(auth, robot, msg, s['id'], chart, source, type, timePeriod)
            else
              msg.reply "Sorry, couldn't find any spaces by name #{space}"
          else
            msg.reply "Unable to get list of spaces from librato :(\nStatus Code: #{res.statusCode}\nBody:\n\n#{body}"

getChartForSpace = (auth, robot, msg, spaceId, chartName, source, type, timePeriod) ->
  url = "https://metrics-api.librato.com/v1/spaces/#{escape(spaceId)}/charts"
  robot.http(url)
      .headers(Authorization: auth, Accept: 'application/json')
      .get() (err, res, body) ->
        switch res.statusCode
          when 200
            json = JSON.parse(body)
            chart = findByName(chartName, json)
            if chart 
              createSnapshotForChart(auth, robot, msg, chart['id'], source, type, timePeriod)
            else
              msg.reply "Could not find chart #{chartName} in that space"

          else
            msg.reply "Unable to get list of spaces from librato :(\nStatus Code: #{res.statusCode}\nBody:\n\n#{body}"

createSnapshotForChart = (auth, robot, msg, chartId, source, type, timePeriod) ->
  url = "https://metrics-api.librato.com/v1/snapshots"
  data = {
    "subject": {
      "chart":{
        "source": source,
        "id": chartId,
        "type": type
      }
    },
    "duration": parseTimePeriod(timePeriod)
  }
  robot.http(url)
      .headers(Authorization: auth, Accept: 'application/json', 'Content-Type': 'application/json')
      .post(JSON.stringify(data)) (err, res, body) ->
        switch res.statusCode
          when 202
            json = JSON.parse(body)
            getSnapshotImage(auth, robot, msg, json['href'])
          else
            msg.reply "Unable to create a snapshot of that chart from librato :(\nStatus Code: #{res.statusCode}\nBody:\n\n#{body}"

getSnapshotImage = (auth, robot, msg, url) ->
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
                getSnapshotImage(auth, robot, msg, url)
              ), 100
          else
            msg.reply "Unable to get a snapshot of that chart from librato :(\nStatus Code: #{res.statusCode}\nBody:\n\n#{body}"

findByName = (name, items) ->
  for i in items
    return i if i['name'] == name

printSpaces = (msg, json) -> 
  printQueryNames(msg, 'spaces', json)

printQueryNames = (msg, key, json) -> 
  found = json['query']['found']
  if found < 1
    msg.reply "Sorry, couldn't find any #{key}"
  else
    printNames(msg, key, json[key])

printNames = (msg, key, json) ->
  names = json.reduce (acc, item) -> acc + "\n" + item.name
  msg.reply "I found #{names.length} #{key}\n\n #{names}"

printCharts = (msg, json) -> 
  printNames(msg, 'charts', json)


module.exports = (robot) ->
  robot.respond /graph spaces/i, (msg) ->
    user = process.env.HUBOT_LIBRATO_USER
    pass = process.env.HUBOT_LIBRATO_TOKEN
    auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64')
    getSpaces(auth, robot, msg)

  robot.respond /graphs ([\w\.:\- ]+?)\s*$/i, (msg) ->
    space = msg.match[1]

    user = process.env.HUBOT_LIBRATO_USER
    pass = process.env.HUBOT_LIBRATO_TOKEN
    auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64')
    getChartsForSpace(auth, robot, msg, space)

  robot.respond /graph me ([\w\.:\- ]+?)\/([\w\.:\- ]+?)\s*(?:over the (?:last|past)? )?(\d+ (?:second|minute|hour|day|week)s?)?(?: source (.+))?(?: type (.+))?$/i, (msg) ->
    space = msg.match[1]
    chart = msg.match[2]
    timePeriod = msg.match[3] || 'hour'
    source = msg.match[4] || '*'
    type = msg.match[5] || 'line'

    user = process.env.HUBOT_LIBRATO_USER
    pass = process.env.HUBOT_LIBRATO_TOKEN
    auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64')

    getSnapshot(auth, robot, msg, space, chart, source, type, timePeriod)