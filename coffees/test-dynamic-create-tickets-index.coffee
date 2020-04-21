assert = require 'assert'
cheerio = require 'cheerio'
request = require 'supertest'
agent = request.agent '127.0.0.1:3003'

describe 'route /admin/dynamic-indexes::',->
  it 'access successful if authenticate good::',->
    agent.post '/admin/login'
      .type 'form'
      .send {'alias':'fengfeng2','password':'1234567'}
      .expect 303
  describe 'route GET /admin/dynamic-indexes::',->
    any = undefined
    before ->
      any = agent.get '/admin/dynamic-indexes'
    it 'should access ok without auth::',->
      any
        .expect 'Content-Type','text/html; charset=utf-8'
        .expect 200
    it 'should get a page content::',->
      any 
        .then (res)->
          $ = cheerio.load res.text
          # has head1 text is 'Select tickets range' 
          assert.equal $('h1').text(),'Select Tickets Range'
          # has one form,2 input fields,one is 'start',another is 'end'
          assert.equal $('form [name=start]').length,1
          assert.equal $('form [name=end]').length,1
  describe 'route POST /admin/dynamic-indexes::',->
    it 'post the form will get response(json)::',->
       agent.post '/admin/dynamic-indexes'
         .type 'form'
         .send {start:100,end:300}
         .expect 200 
         .then (res)->
           assert.equal 'true',res.body.has
