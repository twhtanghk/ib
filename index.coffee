http = require 'needle'
http.defaults json: true
{URL} = require 'url'
{incoming, outgoing} = require('mqtt-level-store') './data'

class IB
  @props:
    curr: '31'
    last: '7296'
    low: '71'
    high: '70'
    diff: '82'
    diffPercent: '83'

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
      .on 'close', ->
        console.debug "#{url.href}/ws disconnected"
      .on 'message', (msg) =>
        msg = await @convert msg
        if Object.keys(msg.quote).length
          msg.src = 'ib'
          @client.mqtt.publish process.env.MQTTTOPIC, JSON.stringify msg
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

  convert: (msg) ->
    ret = quote: {}
    try
      msg = JSON.parse msg.toString()
      if process.env.DEBUG == 'true'
        console.debug msg
      if 'conid' of msg
        ret.symbol = await @symbol msg.conid
      if '_updated' of msg
        ret.lastUpdatedAt = msg._updated
      if IB.props.curr of msg
        ret.quote.curr = parseFloat msg[IB.props.curr]
      if IB.props.last of msg
        ret.quote.last = parseFloat msg[IB.props.last]
      if IB.props.low of msg and IB.props.high of msg
        ret.quote.lowHigh = [
          parseFloat msg[IB.props.low]
          parseFloat msg[IB.props.high]
        ]
      if IB.props.diff of msg and IB.props.diffPercent of msg
        ret.quote.change = [
          parseFloat msg[IB.props.diff]
          parseFloat msg[IB.props.diffPercent]
        ]
      return ret
    catch err
      console.error err

  accounts: ->
    (await http 'get', "#{@url}/portfolio/accounts")
      .body

  subscribe: (symbol) ->
    opts = JSON.stringify
      tempo: 5000
      snapshot: true
    @client.ws
      ?.send "s+md+#{await @conid symbol}+#{opts}"

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
