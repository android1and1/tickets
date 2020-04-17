request = require 'supertest'
app = require '../app'
describe 'it is the first time working with supertest,mocha::',->
  it 'should authenticate success::',->
    request(app)
      .get '/'
      .expect(200,/Placeholder/)


