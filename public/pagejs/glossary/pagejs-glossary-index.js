// Generated by CoffeeScript 2.3.1
(function() {
  $(function() {
    $('form#search').on('submit', function(e) {
      e.preventDefault();
      e.stopPropagation();
      // do some validation
      return $.ajax({
        url: '/glossary/search',
        type: 'POST',
        data: $(this).serialize(),
        dataType: 'json'
      }).done(function(json) {
        var $4sp, $h2, $ul, k, ref, v;
        $h2 = $('<h4/>', {
          text: json.servertime
        });
        $ul = $('<ul/>');
        $4sp = '&nbsp;'.repeat(4);
        ref = json.detail;
        for (k in ref) {
          v = ref[k];
          $ul.append('<li><h4>' + k + '</h4>' + $4sp + v + '</li>');
        }
        // component all.
        $('form#search').before($h2);
        return $('form#search').before($ul);
      }).fail(function(one, two, three) {
        console.log(one);
        console.log(two);
        return console.log(three);
      });
    });
    
    // trigger
    return $('button.glossary-delete').on('click', function(e) {
      var $button, triggerid;
      e.preventDefault();
      e.stopPropagation();
      // trigger server side delete event. via ajax.
      triggerid = $(this).data('id');
      $button = $(this);
      return $.ajax({
        url: '/glossary/delete',
        type: 'POST',
        dataType: 'json',
        data: {
          id: parseInt(triggerid)
        }
      }).done(function(json) {
        $('#delete-response').append($('<h4/>', {
          text: json.status
        }));
        // delete table-tr too.
        return $button.parents('tr').remove();
      }).fail(function(one, two, three) {
        return console.log(one, two, three);
      });
    });
  });

}).call(this);
