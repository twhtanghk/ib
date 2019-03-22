http = require 'needle'
http.defaults json: true
{URL} = require 'url'
{incoming, outgoing} = require('mqtt-level-store') './data'

class IB
  url: new URL process.env.IBURL || "https://ib:5000/v1/portal"

  client:
    ws: null
    mqtt: null

  constructor: ->
    WebSocket = require 'ws'
    url = new URL @url.href
    url.protocol = 'wss'
    @client.ws = new WebSocket "#{url.href}/ws"
      .on 'open', ->
        console.debug "#{url.href}/ws connected"
      .on 'message', (msg) =>
        try
          msg = JSON.parse msg.toString()
        catch err
          console.error err
        msg.symbol = await @symbol msg.conid
        console.log msg
    @client.mqtt = require 'mqtt'
      .connect process.env.MQTTURL,
        username: process.env.MQTTUSER
        clientId: process.env.MQTTCLIENT
        incomingStore: incoming
        outgoingStore: outgoing
      .on 'connect', =>
        console.debug 'mqtt connected'
        @client.mqtt
          .subscribe "#{process.env.MQTTTOPIC.split('/')[0]}/#", qos: 2
      .on 'message', (topic, msg) =>
        try
          {action, data} = JSON.parse msg.toString()
        catch err
          console.error err
        if action == 'subscribe'
          data.map (symbol) =>
            @subscribe symbol

  accounts: ->
    (await http 'get', "#{@url}/portfolio/accounts")
      .body

  subscribe: (symbol) ->
    @client.ws
      ?.send "s+md+#{await @conid symbol}+{\"tempo\":2000,\"snapshot\":true}"

  unsubscribe: (symbol) ->
    @client.ws
      ?.send "u+md+#{await @conid symbol}"

  conid: (symbol) ->
    {conid} = (await http 'post', "#{@url}/iserver/secdef/search", symbol: symbol)
      .body[0]
    conid

  symbol: (conid) ->
    {symbol} = (await http 'get', "#{@url}/iserver/contract/#{conid}/info")
      .body
    parseInt symbol

  quote: (symbol) ->
    conid = await @conid symbol
    res = (await http 'get', "#{@url}/iserver/marketdata/snapshot?conids=#{conid}")
      .body[0]
    return
      src: 'ib'
      symbol: symbol
      quote:
        curr: parseFloat res['31']
        last: parseFloat res['7296']
        lowHigh: [
          parseFloat res['71']
          parseFloat res['70']
        ]
        change: [parseFloat(res['82']), parseFloat(res['83'])]
      lastUpdatedAt: res['_updated']

module.exports = IB
