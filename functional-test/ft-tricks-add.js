// Generated by CoffeeScript 2.3.1
(function() {
  // tricks is route for 'saving/updating/deleting/finding' tricks-db (a nohm-like database)

  // first check if redis-server is running,if at macbook air,it is not running as a service
  // we should manually start it,
  // in this standalone test,we can run "redis-server ./redisdb/redis.conf && mocha <this-test-script.js>"
  var Browser, app, assert, browser, pgrep, server, spawn, tellAndExit;

  assert = require('assert');

  Browser = require('zombie');

  Browser.localhost('www.fellow5.cn', 4140);

  browser = new Browser();

  browser.waitDuration = '30s';

  app = require('../app.js');

  server = (require('http')).Server(app);

  ({spawn} = require('child_process'));

  pgrep = spawn('/usr/bin/pgrep', ['redis-server', '-l']);

  pgrep.on('close', function(code) {
    //console.log 'pgrep inspect redis-server process is:',code
    if (code !== 0) {
      return tellAndExit();
    }
  });

  tellAndExit = function() {
    console.log('You MUST start redis-server ./redisdb/redis.conf first(special for apple macbook air user).');
    console.log('alternatively,can run this:');
    console.log('\t\t"redis-server ./redisdb/redis.conf && mocha <this-test-script.js>"');
    return process.exit(1);
  };

  server.on('error', function(err) {
    console.log('///////');
    console.error(err);
    return console.log('///////');
  });

  server.listen(4140);

  describe('it will be successfully while accessing /tricks/add::', function() {
    before(function() {
      return browser.visit('http://www.fellow5.cn/tricks/add');
    });
    after(function() {
      return server.close();
    });
    it('it will be success while accessing route - /tricks/add::', function() {
      browser.assert.success();
      return browser.assert.status(200);
    });
    it('page has a div its id is deadline::', function() {
      return browser.assert.element('div#deadline');
    });
    it('The 3 fields  all have its name attribute::', function() {
      return browser.assert.elements('.form-control[name]', 3);
    });
    it('The form action is same url.href and method is POST::', function() {
      browser.assert.attribute('form', 'action', '');
      return browser.assert.attribute('form', 'method', 'POST');
    });
    it('at first time there just one "+1" button::', function() {
      return browser.assert.elements('button.onemore', 1);
    });
    it.skip('click +1 button one time,the button.onemore elements has 2::', function(done) {
      return browser.pressButton('+ 1', function() {
        browser.assert.elements('button.onemore', 2);
        return done();
      });
    });
    return describe('submit form::', function() {
      before(function() {
        browser.fill('[name=content]', 'there was a game between county a and country b,\nlong long ago..');
        browser.fill('[name=about]', 'aboutone');
        browser.fill('[type=number]', '1111');
        return browser.pressButton('button');
      });
      return it('should ajax get new element - "div.alert.alert-info"::', function() {
        return browser.assert.element('div.alert.alert.alert-info');
      });
    });
  });

}).call(this);
