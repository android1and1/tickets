// Generated by CoffeeScript 2.3.2
(function() {
  $(function() {
    var displayQrcode, socket;
    socket = io();
    socket.on('message', function(msg) {
      return $('div#messagebox').append('<u>Server Send:' + msg + '</u>');
    });
    socket.on('connect', function() {
      return $('div#messagebox').append('<p>hi,socket connected.</p>');
    });
    socket.on('dare', function(msg) {
      return alert('server said:' + msg);
    });
    $('button#trigger').on('click', function(e) {
      socket.emit('createqrcode', 'you are beautiful.', displayQrcode);
      return e.stopPropagation();
    });
    return displayQrcode = function(url) {
      return $('div#messagebox').append($('<img/>', {
        src: url,
        alt: 'itis a qr code img',
        width: '34%'
      }));
    };
  });

}).call(this);
