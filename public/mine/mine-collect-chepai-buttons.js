// Generated by CoffeeScript 2.3.1
(function() {
  $(function() {
    $('button').on('click', function(evt) {
      if (!$(this).hasClass('yesido')) {
        alert('your input is ' + evt.target.value);
        evt.preventDefault();
        return evt.stopPropagation();
      }
    });
    return $('a[type=button]').on('click', function(evt) {
      return alert('link of ' + $(this).text());
    });
  });

}).call(this);
