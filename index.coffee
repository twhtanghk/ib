http = require 'needle'
http.defaults json: true
opts =
  rejectUnauthorized: false

ib =
  url: process.env.IBURL || "https://ib:5000/v1/portal"
  accounts: ->
    (await http 'get', "#{@url}/portfolio/accounts", opts)
      .body
  quote: (symbol) ->
    {conid, companyName} =(await http 'post', "#{@url}/iserver/secdef/search", symbol: symbol, opts)
      .body[0]
    res = (await http 'get', "#{@url}/iserver/marketdata/snapshot?conids=#{conid}", opts)
      .body[0]
    return
      symbol: symbol
      name: companyName
      price:
        curr: parseFloat res['31']
        high: parseFloat res['70']
        low: parseFloat res['71']
        last: parseFloat res['7296']
        change: [parseFloat(res['82']), parseFloat(res['83'])]
      lastUpdatedAt: new Date res['_updated']

{incoming, outgoing} = require('mqtt-level-store') './data'
client = require 'mqtt'
  .connect process.env.MQTTURL,
    username: process.env.MQTTUSER
    clientId: process.env.MQTTCLIENT
    incomingStore: incoming
    outgoingStore: outgoing
  .on 'connect', ->
    client.subscribe process.env.MQTTTOPIC, qos: 2
    console.debug 'mqtt connected'

{Readable, Transform} = require 'stream'

class IBCron extends Readable
  symbols: []

  crontab: process.env.CRONTAB || '0 */5 9-16 * * 1-5'

  constructor: ({@contrab} = {}) ->
    super objectMode: true

    # check if message contains {action: 'subscribe', data: [1, 1156]}
    # and update symbol list
    client.on 'message', (topic, msg) =>
      try
        {action, data} = JSON.parse msg
      catch err
        console.error "#{msg}: #{err.toString()}"
      if action == 'subscribe'
        asc = (a, b) ->
          a - b
        data.sort asc
        for i in data
          if i not in @symbols
            @symbols.push i
        @symbols.sort asc
        console.debug "update symbols: #{@symbols}"

    require 'node-schedule'
      .scheduleJob @crontab, =>
        console.debug "get quote for #{@symbols} at #{new Date().toLocaleString()}"
        @symbols.map (symbol) ->
          try
            @emit 'data', await ib.quote symbol
          catch err
            console.error "#{symbol}: #{err.toString()}"

  _read: ->
    false

class IBMqtt extends Transform
  constructor: (opts = {objectMode: true}) ->
    super opts

  _transform: (data, encoding, cb) ->
    client.publish process.env.MQTTTOPIC, JSON.stringify data
    @push data
    cb()

module.exports = {ib, IBCron, IBMqtt}
