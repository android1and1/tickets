// Generated by CoffeeScript 2.3.1
(function() {
  $(function() {
    var loadimage;
    // define an aync func
    loadimage = function(url) {
      return new Promise(function(onresolved, onrejected) {
        var img;
        img = new Image;
        img.onload = onresolved;
        img.onerror = onrejected;
        return img.src = url;
      });
    };
    //loadimage '/images/flops-thumb.jpg'
    return loadimage('/images/no-this.jpg').then(function() {
      return console.log('load complete.');
    }).catch(function(reason) {
      return console.log('catched:', reason);
    });
  });

}).call(this);
