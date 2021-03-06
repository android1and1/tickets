// Generated by CoffeeScript 2.1.1
(function() {
  $(function() {
    // this script show how invoke button.js(bootstrap native js component).
    // at page-code(html),defines a button like this: <button id="xxx" type="button" data-xxx-text="xxx">..</button>
    // the most important is 'data-xxx-text' which 'xxx' means anything you given.
    return $('button').on('click', function(evt) {
      var ans;
      // check target ether effective or not.
      ans = $(this).attr('data-accept-text');
      if (ans !== void 0 && ans.length !== 0) {
        $(this).button('accept');
        return (function(context) {
          return setTimeout(function() {
            return context.button('reset');
          }, 2000);
        })($(this));
      }
    });
  });

}).call(this);
