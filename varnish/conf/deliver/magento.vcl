#
if (req.http.X-Varnish-Faked-Session) {
set resp.http.Set-Cookie = req.http.X-Varnish-Faked-Session +
"; expires=" + resp.http.X-Varnish-Cookie-Expires + "; path=/";
if (req.http.Host) {
if (req.http.User-Agent ~ "^(?:ApacheBench/.*|.*Googlebot.*|JoeDog/.*Siege.*|magespeedtest\.com|Nexcessnet_Turpentine/.*)$") {
set resp.http.Set-Cookie = resp.http.Set-Cookie +
"; domain=" + regsub(req.http.Host, ":\d+$", "");
} else {
if(req.http.Host ~ "") {
set resp.http.Set-Cookie = resp.http.Set-Cookie +
"; domain=";
} else {
set resp.http.Set-Cookie = resp.http.Set-Cookie +
"; domain=" + regsub(req.http.Host, ":\d+$", "");
}
}
}
set resp.http.Set-Cookie = resp.http.Set-Cookie + "; httponly";
unset resp.http.X-Varnish-Cookie-Expires;
}
if (req.http.X-Varnish-Esi-Method == "ajax" && req.http.X-Varnish-Esi-Access == "private") {
set resp.http.Cache-Control = "no-cache";
}
##if (true || client.ip ~ debug_acl) {
##set resp.http.X-Varnish-Hits = obj.hits;
##set resp.http.X-Varnish-Esi-Method = req.http.X-Varnish-Esi-Method;
##set resp.http.X-Varnish-Esi-Access = req.http.X-Varnish-Esi-Access;
##set resp.http.X-Varnish-Currency = req.http.X-Varnish-Currency;
##set resp.http.X-Varnish-Store = req.http.X-Varnish-Store;
##} else {
unset resp.http.X-Varnish;
unset resp.http.Via;
unset resp.http.X-Powered-By;
unset resp.http.Server;
unset resp.http.X-Turpentine-Cache;
unset resp.http.X-Turpentine-Esi;
unset resp.http.X-Turpentine-Flush-Events;
unset resp.http.X-Turpentine-Block;
unset resp.http.X-Varnish-Session;
unset resp.http.X-Varnish-Host;
unset resp.http.X-Varnish-URL;
unset resp.http.X-Varnish-Set-Cookie;
##}
        if (obj.hits > 0) {
            set resp.http.X-Cache      = "HIT";
        } else {
            set resp.http.X-Cache      = "MISS";
        }

