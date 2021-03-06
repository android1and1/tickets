// Generated by CoffeeScript 2.3.1
(function() {

  /*
  help methods
  */
  var DB_PREFIX, Nohm, TABLE_PREFIX, counter, express, formidable, fs, handleArraySave, handleSingleSave, nohm, nohm2, path, pug, router, schema;

  fs = require('fs');

  pug = require('pug');

  path = require('path');

  express = require('express');

  router = express.Router();

  formidable = require('formidable');

  schema = require('../modules/sche-tricks.js');

  DB_PREFIX = schema.prefixes[0];

  TABLE_PREFIX = schema.prefixes[1];

  Nohm = require('nohm');

  [nohm, nohm2] = [Nohm.Nohm, Nohm.Nohm];

  [nohm, nohm2].forEach(function(itisnohm) {
    var Redis, redis;
    // now we have 2 redis clients.
    Redis = require('redis');
    redis = Redis.createClient();
    redis.on('error', function(err) {
      return console.log('debug info::route-tricks::', err.message);
    });
    return redis.on('connect', function() {
      itisnohm.setClient(redis);
      return itisnohm.setPrefix(DB_PREFIX);
    });
  });

  //counter
  counter = 0;

  // the first time,express working with nohm - redis orm library
  router.get('/', function(req, res, next) {
    // default index page display 10 items -- top10
    return res.redirect(302, '/tricks/head10');
  });

  router.get('/head:number', async function(req, res, next) {
    var id, ids, ins, items, j, len, number, total_items_length;
    number = req.params.number;
    //ids = await schema.sort({field:'about',direction:'DESC',limit:[0,10]}) 
    ids = (await schema.find());
    total_items_length = ids.length;
    ids = ids.slice(-1 * number);
    ids = ids.reverse();
    items = [];
    if (ids.length > 0) {
      for (j = 0, len = ids.length; j < len; j++) {
        id = ids[j];
        ins = (await schema.load(id));
        items.push(ins.allProperties());
      }
      return res.render('tricks/list-items.pug', {
        retrieved: ids.length,
        total: total_items_length,
        items: items
      });
    } else {
      return res.render('tricks/list-items.pug', {
        idle: true
      });
    }
  });

  router.get('/sample-html2form', function(req, res, next) {
    return res.send('ok');
  });

  router.get('/delete/:id', async function(req, res, next) {
    var error, ins;
    try {
      ins = (await schema.load(req.params.id));
      ins.remove({
        silence: true
      });
      return res.render('tricks/delete', {
        itemid: req.params.id
      });
    } catch (error1) {
      error = error1;
      return res.render('tricks/delete', {
        itemid: req.params.id,
        error: error.message
      });
    }
  });

  router.get('/detail/:number', async function(req, res, next) {
    var about, content, error, id, obj, visits;
    // the detail page always reference from /head:id,but its data is newly loaded from db.
    id = req.params.number;
    try {
      obj = (await schema.load(id));
      ({about, content, visits} = obj.allProperties());
      return res.render('tricks/detail-page', {
        id: id,
        about: about,
        visits: visits,
        content: content
      });
    } catch (error1) {
      error = error1;
      return res.render('tricks/detail-page', {
        id: id,
        error: error.message
      });
    }
  });

  router.get('/add', function(req, res, next) {
    return res.render('tricks/add.pug', {
      order: counter++
    });
  });

  router.get('/gethappy', function(req, res, next) {
    return res.json({
      'received': req.query.id
    });
  });

  router.post('/add', async function(req, res, next) {
    var response;
    if (req.body.sign === '1') {
      response = (await handleSingleSave(req.body));
      return res.json(response);
    } else {
      response = (await handleArraySave(parseInt(req.body.sign), req.body));
      return res.json(response);
    }
  });

  router.post('/onemore', function(req, res, next) {
    //note that,"pug.renderFile" retrieves .pug path,not same as "res.render"
    // res.render works from root directory - "<project>/views"
    return res.send(pug.renderFile('views/tricks/snippet-form.pug', {
      order: counter++
    }));
  });

  handleSingleSave = async function(body) {
    var trick, valid;
    // save event via standlone redis client - 'nohm2'
    trick = (await nohm2.factory(TABLE_PREFIX));
    trick.property({
      about: body.about,
      content: body.content,
      visits: body.visits,
      moment: Date.parse(new Date())
    });
    valid = (await trick.validate(void 0, false));
    if (!valid) {
      
      //console.dir trick.errors
      // return a promise
      return Promise.resolve({
        status: 'error',
        title: 'failure due to database suit',
        errors: trick.errors
      });
    } else {
      return trick.save().then(function() {
        return Promise.resolve({
          status: 'successfully',
          content: trick.allProperties()
        });
      });
    }
  };

  handleArraySave = function(length, body) {
    var allthings;
    allthings = (function() {
      var results = [];
      for (var j = 0; 0 <= length ? j < length : j > length; 0 <= length ? j++ : j--){ results.push(j); }
      return results;
    }).apply(this).map(function(i) {
      return handleSingleSave({
        about: body["about"][i],
        content: body["content"][i],
        visits: body["visits"][i]
      });
    });
    return Promise.all(allthings);
  };

  module.exports = router;

}).call(this);
