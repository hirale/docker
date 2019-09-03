#
set beresp.grace = 15s;
set beresp.http.X-Varnish-Host = bereq.http.host;
set beresp.http.X-Varnish-URL = bereq.url;
if (bereq.url ~ "^(/media/|/skin/|/js/|/)(?:(?:index|litespeed)\.php/)?") {
unset beresp.http.Vary;
set beresp.do_gzip = true;
if (beresp.status != 200 && beresp.status != 404) {
set beresp.ttl = 15s;
set beresp.uncacheable = true;
return (deliver);
} else {
if (beresp.http.Set-Cookie) {
if (beresp.http.set-cookie ~ "adminhtml=") {
        set beresp.uncacheable = true;
        return (deliver);
   } else {
     set beresp.http.X-Varnish-Set-Cookie = beresp.http.Set-Cookie;
     unset beresp.http.Set-Cookie;
   }
}
unset beresp.http.Cache-Control;
unset beresp.http.Expires;
unset beresp.http.Pragma;
unset beresp.http.Cache;
unset beresp.http.Age;
if (beresp.http.X-Turpentine-Esi == "1") {
set beresp.do_esi = true;
}
if (beresp.http.X-Turpentine-Cache == "0") {
set beresp.ttl = 15s;
set beresp.uncacheable = true;
return (deliver);
} else {
if (true &&
bereq.url ~ ".*\.(?:css|js|jpe?g|png|gif|ico|swf)(?=\?|&|$)") {
set beresp.ttl = 28800s;
set beresp.http.Cache-Control = "max-age=28800";
} elseif (bereq.http.X-Varnish-Esi-Method) {
if (bereq.http.X-Varnish-Esi-Access == "private" &&
bereq.http.Cookie ~ "frontend=") {
set beresp.http.X-Varnish-Session = regsub(bereq.http.Cookie,
"^.*?frontend=([^;]*);*.*$", "\1");
}
if (bereq.http.X-Varnish-Esi-Method == "ajax" &&
bereq.http.X-Varnish-Esi-Access == "public") {
set beresp.http.Cache-Control = "max-age=" + regsub(
bereq.url, ".*/ttl/(\d+)/.*", "\1");
}
set beresp.ttl = std.duration(
regsub(
bereq.url, ".*/ttl/(\d+)/.*", "\1s"),
300s);
if (beresp.ttl == 0s) {
set beresp.ttl = 15s;
set beresp.uncacheable = true;
return (deliver);
}
} else {
set beresp.ttl = 3600s;
}
}
}
return (deliver);
}

