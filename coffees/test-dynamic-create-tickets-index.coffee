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
  describe 'route GET /admin/dynamic-indexes?range=100::',->
    it 'after authentication,agent access this route should be ok::',->
      agent.get '/admin/dynamic-indexes'
        .expect 'Content-Type','text/html; charset=utf-8'
        .expect 200
        .then (res)->
          $ = cheerio.load res.text
          # has head1 text is 'Range List' 
          assert.equal $('h1').text(),'Range List'
          # because invalid range,server send no list,view display none
          assert.equal $('.list-group').length,0 
  describe 'if query is invalidString responses also has waringing:',->
    it 'get via query range=invalid should get warning::',->
      agent.get '/admin/dynamic-indexes?range=invalid',->
        .expect 200
        .then (res)->
           $ = cheerio.load res.text
           # has .warning element in this DOM.
           assert.equal 1,$('.warning').length
  describe 'route POST /admin/dynamic-indexes::',->
    it 'post the form will get response(json)::',->
      agent.post '/admin/dynamic-indexes'
        .type 'form'
        .send {start:300,end:550}
        .expect 200 
        .then (res)->
          # this time ,response titles will more than 200
          $ = cheerio.load res.text
          assert.ok $('.list-group-item').length>200 
