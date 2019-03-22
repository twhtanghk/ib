IB  = require '../index'

do ->
  try
    ib = new IB()
    console.log await ib.accounts()
    console.log await ib.quote 366
    conid = await ib.conid 366
    console.log await ib.symbol conid
  catch err
    console.error err
  
