Browser = require 'zombie'
Browser.localhost 'example.com',4140
browser = new Browser
app = require '../app'
http = require 'http'
server = http.Server app
server.listen 4140
server.on 'error',(err)->console.error err

# sometimes it will help(below line)
#browser.waitDuration = '30s'
describe 'zombie ability display::',->
  after ->
    server.close()
  describe 'access index page should success::',->
    before ->
      browser.visit 'http://example.com'
    it 'should access page successfully::',->
      browser.assert.success()
      #No Need This Time
      #console.log browser.html()
    it 'this page has more than 10 link tags::',->
      browser.assert.elements 'a',{atleast:10}
    it 'page title is "welcome-daka"::',->
      browser.assert.text 'title','welcome-daka' 
