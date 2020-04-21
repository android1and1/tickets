// Generated by CoffeeScript 2.4.1
(function() {
  var agent, assert, cheerio, request;

  assert = require('assert');

  cheerio = require('cheerio');

  request = require('supertest');

  agent = request.agent('127.0.0.1:3003');

  describe('route /admin/dynamic-indexes::', function() {
    it('access successful if authenticate good::', function() {
      return agent.post('/admin/login').type('form').send({
        'alias': 'fengfeng2',
        'password': '1234567'
      }).expect(303);
    });
    describe('route GET /admin/dynamic-indexes::', function() {
      var any;
      any = void 0;
      before(function() {
        return any = agent.get('/admin/dynamic-indexes');
      });
      it('should access ok without auth::', function() {
        return any.expect('Content-Type', 'text/html; charset=utf-8').expect(200);
      });
      return it('should get a page content::', function() {
        return any.then(function(res) {
          var $;
          $ = cheerio.load(res.text);
          // has head1 text is 'Select tickets range' 
          assert.equal($('h1').text(), 'Select Tickets Range');
          // has one form,2 input fields,one is 'start',another is 'end'
          assert.equal($('form [name=start]').length, 1);
          return assert.equal($('form [name=end]').length, 1);
        });
      });
    });
    return describe('route POST /admin/dynamic-indexes::', function() {
      return it('post the form will get response(json)::', function() {
        return agent.post('/admin/dynamic-indexes').type('form').send({
          start: 100,
          end: 300
        }).expect(200).then(function(res) {
          return assert.equal('true', res.body.has);
        });
      });
    });
  });

}).call(this);
