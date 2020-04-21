request = require 'supertest'
assert = require 'assert'
agent = undefined

describe 'project unit test::',->
  before ->
    agent = request 'http://localhost:3003' 

  it 'should access first page successfully::',->
    agent.get '/'
      .expect 200
  it 'should access first page successfully::',->
    agent.get '/'
      .then (res)->
        assert.notEqual -1,(res.text.indexOf 'placeholder')
describe 'check words::',->
  it 'should get 5 alpha::',->
    agent.get '/create-check-words'
      .expect 200
      .expect /\"[0-9a-z]{5}\"/  #期待有一个由数字和字母组成的五位字符并包裹在一对双引号里。 
describe 'authenticate test::',->
  after ->
    process.exit 0 
  it 'should be redirected if authenticate successful::',->
    agent.post '/admin/login'
      .send 'alias=fool&password=1234567' 
      .expect 303 
