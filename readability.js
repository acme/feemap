var readability = require('node-readability')
var argv = require('optimist')
  .usage('Usage: $0 --url [url]')
  .demand(['url'])
  .argv;

var url = argv.url;
readability.read(url,
function(err, article) {
  if (err) {
    console.error(err);
    process.exit(1);
  }
  var html = '<html><head><meta charset="utf-8"></head><body><h1>Readability</h1>'
    + article.getContent()
    + '</body></html>';
  console.log(html);
  process.exit(0);
});
