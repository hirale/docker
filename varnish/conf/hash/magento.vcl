#
if(false && req.http.X-Varnish-Cache-Url) {
hash_data(req.http.X-Varnish-Cache-Url);
} else {
hash_data(req.url);
}
if (req.http.Host) {
hash_data(req.http.Host);
} else {
hash_data(server.ip);
}
hash_data(req.http.Ssl-Offloaded);
if (req.http.X-Normalized-User-Agent) {
hash_data(req.http.X-Normalized-User-Agent);
}
if (req.http.Accept-Encoding) {
hash_data(req.http.Accept-Encoding);
}
if (req.http.X-Varnish-Store || req.http.X-Varnish-Currency) {
hash_data("s=" + req.http.X-Varnish-Store + "&c=" + req.http.X-Varnish-Currency);
}
if (req.http.X-Varnish-Esi-Access == "private" &&
req.http.Cookie ~ "frontend=") {
hash_data(regsub(req.http.Cookie, "^.*?frontend=([^;]*);*.*$", "\1"));
}
return (lookup);

