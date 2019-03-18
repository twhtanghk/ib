{Writable} = require 'stream'
{ib, IBCron, IBMqtt}  = require '../index'

do ->
  try
    console.log await ib.accounts()
    console.log await ib.quote 366
    (await new IBCron())
      .pipe new IBMqtt()
      .pipe new Writable objectMode: true, write: (data, encoding, cb) ->
        console.log data
        cb()
  catch err
    console.error err
  
