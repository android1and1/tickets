// Generated by CoffeeScript 2.3.1
(function() {
  /*
    target: public/pagejs/tricks/pagejs-tricks-onemoreform.js
    work with route - ./tricks/add
    work with view - ./views/tricks/snippet-form.pug
  */
  jQuery(document).ready(function() {
    var makealertbox;
    // help func
    makealertbox = function(info) {
      return $('<div class="alert alert-info"><button class="close" type="button" data-dismiss="alert"><span> &times </span></button><h3>' + info + '</h3></div>');
    };
    $('button#submit').on('click', function(evt1) {
      // debug info
      //alert $('form').serialize()
      $.ajax({
        url: '',
        dataType: 'text',
        data: $('form').serialize(),
        type: 'POST'
      }).done(function(jsontext) {
        return $('div#deadline').append(makealertbox(jsontext));
      }).fail(function(xhr, status, code) {
        console.log(status);
        return console.log(code);
      });
      return false;
    });
    return $('form').on('click', 'button.onemore', function(evt2) {
      var original;
      // sign = 1 + N 
      original = parseInt($('input#behidden').val());
      $('input#behidden').val(original + 1);
      $.ajax({
        url: '/tricks/onemore',
        dataType: 'text',
        type: 'POST'
      }).done(function(text) {
        // first, change button class from .onemore to .onemoredone
        $('button.onemore').attr('disabled', 'disabled');
        return $('div#deadline').append(makealertbox(text));
      }).fail(function(xhr, status, code) {
        console.log(status);
        return console.log(code);
      });
      return false;
    });
  });

}).call(this);
