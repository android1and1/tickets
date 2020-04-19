request = require 'supertest'
assert = require 'assert'
app = require '../app.js'
server = undefined
agent = undefined

describe 'project unit test::',->
  before ->
    agent = request app 
    server = app.listen 6006

  it 'should access first page successfully::',->
    agent.get '/'
      .expect 200
  it 'should access first page successfully::',->
    agent.get '/'
      .then (res)->
        assert.notEqual -1,(res.text.indexOf 'placeholder')
describe 'authenticate test::',->
  after ->
    server.close()
  it 'should be redirected if authenticate successful::',->
    agent.post '/admin/login'
      .send 'alias=fool&password=1234567' 
      .expect 303 
