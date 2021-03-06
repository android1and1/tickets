// Generated by CoffeeScript 2.4.1
(function() {
  var agent, assert, request;

  request = require('supertest');

  assert = require('assert');

  agent = void 0;

  describe('project unit test::', function() {
    before(function() {
      return agent = request('http://localhost:3003');
    });
    return it('should access first page successfully::', function() {
      return agent.get('/').then(function(res) {
        return assert.notEqual(-1, res.text.indexOf('placeholder'));
      });
    });
  });

  describe('check words::', function() {
    return it('should get 5 alpha::', function() {
      return agent.get('/create-check-words').expect(200).expect(/\"[0-9a-z]{5}\"/); //期待有一个由数字和字母组成的五位字符并包裹在一对双引号里。 
    });
  });

  describe('authenticate test::', function() {
    return it('should be redirected if authenticate successful::', function() {
      return agent.post('/admin/login').send('alias=fool&password=1234567').expect(303);
    });
  });

}).call(this);
