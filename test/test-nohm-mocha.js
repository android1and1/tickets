// Generated by CoffeeScript 2.3.1
(function() {
  var Nohm, NohmModel, Password, Schema, assert, db, nohm;

  assert = require('assert');

  nohm = require('nohm');

  Nohm = nohm.Nohm;

  NohmModel = nohm.NohmModel;

  db = void 0;

  Schema = void 0;

  Password = (function() {
    class Password extends NohmModel {};

    Password.idGenerator = 'increment';

    Password.modelName = 'pass';

    Password.definitions = {
      for_what: {
        type: 'string',
        index: true,
        validations: ['notEmpty']
      },
      pair_text: {
        type: 'string',
        validations: ['notEmpty']
      },
      update_time: {
        type: 'timestamp',
        defaultValue: Date.now()
      },
      visits: {
        defaultValue: 0,
        load_pure: true,
        type: function(newv, key, oldv) {
          // nohm will treat 'oldv' and 'newv' as string,so need parseInt()
          return parseInt(oldv) + 1;
        }
      }
    };

    return Password;

  }).call(this);

  describe('Mocha + Nohm::', function() {
    var client;
    client = (require('redis')).createClient();
    client.on('error', function(err) {
      console.log('\tPlease Check Redis Process,Api Said:\n"%s."\n', err.message);
      return process.exit(1);
    });
    client.on('connect', function() {
      Nohm.setClient(this);
      Nohm.setPrefix('laofu'); // lao fu
      // Dont Forget Register!
      Schema = Nohm.register(Password);
      return db = new Schema;
    });
    return describe('Store Instance As One Item::', function() {
      before(function() {
        return Nohm.purgeDb(client);
      });
      it('should has nothing initial time::', function() {
        return db.find().then(function(something) {
          return assert.equal(something.length, 0);
        });
      });
      it('should store 1 item::', function() {
        db.property('for_what', 'Mac System');
        db.property('pair_text', 'mac-user:chilemeiyou(chi le mei you)');
        db.property('visits', 'Am I?');
        return db.save().then(function(something) {
          return assert.equal(db.id, '1');
        });
      });
      it('should has one item and its property-visits is 1::', function() {
        return db.find().then(async function(something) {
          var item;
          item = (await db.load(something[0]));
          return assert.equal(item.visits, 1);
        });
      });
      it('above item updated then its visits will add 1::', async function() {
        var id, ids, item;
        db.property('visits', 'any');
        await db.save();
        ids = (await db.find({
          'for_what': 'Mac System'
        }));
        id = ids[0];
        item = (await db.load(id));
        return assert.equal(item.visits, 2);
      });
      it('above item updated 3 times then its visits value is 5::', async function() {
        var i, id, ids, item, j;
        for (i = j = 1; j <= 3; i = ++j) {
          db.property('visits', '');
          await db.save();
        }
        ids = (await db.find({
          'for_what': 'Mac System'
        }));
        id = ids[0];
        item = (await db.load(id));
        return assert.equal(item.visits, 5);
      });
      return it('should valide fail because pair_text not given::', function() {
        var db2;
        db2 = new Schema;
        db2.property({
          for_what: 'Jelly-Mac System',
          pair_text: 'root:123',
          update_time: '2013-5-9 14:00:28'
        });
        return db2.save().then(function(ins) {
          return assert.equal(db2.id, 2);
        });
      });
    });
  });

}).call(this);
