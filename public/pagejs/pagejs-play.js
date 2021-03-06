// Generated by CoffeeScript 2.3.2
(function() {
  jQuery('document').ready(function() {
    var $commitbutton;
    // include window.createAlertBox already.
    // so we now invokde it.
    $commitbutton = $('button#commit');
    return $commitbutton.on('click', function() {
      /*
       * display datas.
      for i in  $('form').serializeArray()
        createAlertBox $('#msg'),(i.name + ':' + i.value)
       */
      return $.ajax({
        url: '/play',
        type: 'POST',
        data: $('form').serializeArray(),
        dataType: 'json'
      }).done(function(json) {
        var i, results;
        results = [];
        for (i in json) {
          results.push(createAlertBox($('#msg'), json[i]));
        }
        return results;
      });
    });
  });

}).call(this);
