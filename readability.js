var readability = require('node-readability')
var slurp = require('slurp-stream');
readability.debug(0);

slurp(process.stdin, function(err, html) {
    if(err) throw err;
    var html_buffer = new Buffer(html);
    readability.read(html_buffer.toString(),
    function(err, article) {
        if (err) {
            console.error(err);
            process.exit(1);
        }
        var response = '<html><head><meta charset="utf-8"></head><body><h1>'
            + article.getTitle()
            + '</h1>'
            + article.getContent()
            + '</body></html>';
        console.log(new Buffer(response).toString());
        process.exit(0);
    });
});

