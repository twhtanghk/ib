{ib, IBCron, IBMqtt}  = require '../index'

do ->
 console.log await ib.accounts()
###
 [366, 1122, 3399].map (symbol) ->
   console.log await ib.quote symbol
###
