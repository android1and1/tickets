// Generated by CoffeeScript 2.3.1
(function() {
  var RT, alphaFactory, express, fs, path, pug, router;

  path = require('path');

  fs = require('fs');

  express = require('express');

  router = express.Router();

  // for test md
  RT = require('../modules/md-readingjournals');

  pug = require('pug');

  // a sample of dynatically load .pug text
  router.get('/sample-html2form', function(req, res, next) {
    var opts, snippet;
    opts = RT.definitions;
    opts.url = '/alpha/indexeddb';
    // from RT get a pug-coded text. 
    snippet = pug.render(RT.mod2form(), {
      opts: opts
    });
    return res.render('tianna', {
      snippet: snippet,
      title: 'DEYIJIA'
    });
  });

  router.get('/indexeddb', function(req, res, next) {
    // see safari or firefox window.indexeddb attribute
    return res.render('alpha/indexeddb.pug');
  });

  router.get('/canredirect', function(req, res, next) {
    return res.redirect(302, '/alpha/succ');
  });

  router.get('/ajax-redirect', function(req, res, next) {
    return res.render('alpha/ajax-redirect');
  });

  router.post('/ajax-redirect', function(req, res, next) {
    // client page send an ajax-request to this.
    // server give a json
    // res.json {state:'ok state'} 
    // actually,the ajax-redirect is fake redirect,not via http-headers.
    if (req.body.message === '1') {
      return res.json({
        command: 'redirect',
        state: 'ok'
      });
    } else {
      return res.json({
        state: 'not good!'
      });
    }
  });

  // this route coplay with client-ajax,'json' to client.
  router.post('/server-side-data/:num', function(req, res, next) {
    var pathname;
    pathname = path.join(path.dirname(__dirname), 'share', 'da' + req.params.num + '.json');
    return fs.readFile(pathname, 'utf-8', function(e, da) {
      var msg;
      //if e then res.json JSON.stringify {state:'wrong'} else res.json da
      if (e) {
        msg = 'can not find ' + pathname + ' .';
        return next(msg);
      } else {
        return res.json(da);
      }
    });
  });

  router.get('/succ', function(req, res, next) {
    return res.render('alpha/succ');
  });

  router.get('/*', function(req, res, next) {
    var abs, extname;
    abs = path.join(path.dirname(__dirname), 'views', req.path);
    extname = path.extname(abs);
    if (!fs.existsSync(abs)) {
      return next();
    } else {
      if (extname.toLowerCase() === '.pug') {
        return res.render(req.path.substr(1));
      } else if (extname.toLowerCase() === '.html') {
        return res.sendFile(abs);
      } else {
        console.log(extname);
        return res.send('not clear mime type.');
      }
    }
  });

  router.for = '/alpha';

  alphaFactory = function(whichapp) {
    return function(whichpath) {
      whichapp.use(whichpath, router);
      return null;
    };
  };

  //module.exports = router
  // now ,each router's module currizm.2018-11-28
  module.exports = alphaFactory;

}).call(this);
