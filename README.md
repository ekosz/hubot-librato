# hubot-librato

Librato integration for Hubot

## Installation

In your hubot repository, run:

`npm install hubot-librato --save`

Then add **hubot-librato** to your `external-scripts.json`:

```json
["hubot-librato"]
```

## Configuration

`graph me` requires a bit of configuration to get everything working:

* HUBOT_LIBRATO_USER - Your librato user (example@foo.bar)
* HUBOT_LIBRATO_TOKEN - Found on [your account page](https://metrics.librato.com/account)

## Example interactions

View a graph from librato

```
ekosz> hubot graph me recent exceptions
hubot> ekosz: http://snapshots.librato.com/instrument/xxxxxxxx-9999.png
```

Limit the graph to a time peroid

```
ekosz> hubot graph me purchases over the last 3 hours
hubot> ekosz: http://snapshots.librato.com/instrument/jjjjjjjj-1111.png
```
