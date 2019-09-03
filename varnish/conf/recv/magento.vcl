#
if (!true || req.http.Authorization ||
req.method !~ "^(GET|HEAD|OPTIONS)$" ||
req.http.Cookie ~ "varnish_bypass=1") {
return (pipe);
}
if(false) {
set req.http.X-Varnish-Origin-Url = req.url;
}
set req.url = regsuball(req.url, "(.*)//+(.*)", "\1/\2");
if (req.http.Accept-Encoding) {
if (req.http.Accept-Encoding ~ "gzip") {
set req.http.Accept-Encoding = "gzip";
} else if (req.http.Accept-Encoding ~ "deflate") {
set req.http.Accept-Encoding = "deflate";
} else {
unset req.http.Accept-Encoding;
}
}
if (req.http.cookie ~ "adminhtml=") { 
   set req.backend_hint = admin; 
   return (pipe); 
 }
if (req.url ~ "^(/media/|/skin/|/js/|/)(?:(?:index|litespeed)\.php/)?") {
set req.http.X-Turpentine-Secret-Handshake = "1";
if (req.url ~ "^(/media/|/skin/|/js/|/)(?:(?:index|litespeed)\.php/)?admin") {
set req.backend_hint = admin;
return (pipe);
}
if (req.http.Cookie ~ "\bcurrency=") {
set req.http.X-Varnish-Currency = regsub(
req.http.Cookie, ".*\bcurrency=([^;]*).*", "\1");
}
if (req.http.Cookie ~ "\bstore=") {
set req.http.X-Varnish-Store = regsub(
req.http.Cookie, ".*\bstore=([^;]*).*", "\1");
}
if (req.url ~ "/turpentine/esi/get(?:Block|FormKey)/") {
set req.http.X-Varnish-Esi-Method = regsub(
req.url, ".*/method/(\w+)/.*", "\1");
set req.http.X-Varnish-Esi-Access = regsub(
req.url, ".*/access/(\w+)/.*", "\1");
##if (req.http.X-Varnish-Esi-Method == "esi" && req.esi_level == 0 &&
##!(true || client.ip ~ debug_acl)) {
if (req.http.X-Varnish-Esi-Method == "esi" && req.esi_level == 0 ) {
return (synth(403, "External ESI requests are not allowed"));
}
}
if (req.http.Cookie !~ "frontend=" && !req.http.X-Varnish-Esi-Method) {
#if (client.ip ~ crawler_acl ||
if (req.http.User-Agent ~ "^(?:ApacheBench/.*|.*Googlebot.*|JoeDog/.*Siege.*|magespeedtest\.com|Nexcessnet_Turpentine/.*)$") {
set req.http.Cookie = "frontend=crawler-session";
} else {
return (pipe);
}
}
if (true &&
req.url ~ ".*\.(?:css|js|jpe?g|png|gif|ico|swf)(?=\?|&|$)") {
unset req.http.Cookie;
unset req.http.X-Varnish-Faked-Session;
return (hash);
}
if (req.url ~ "^(/media/|/skin/|/js/|/)(?:(?:index|litespeed)\.php/)?(?:admin|api|cron\.php)" ||
req.url ~ "\?.*__from_store=") {
return (pipe);
}
if (true &&
req.url ~ "(?:[?&](?:__SID|XDEBUG_PROFILE)(?=[&=]|$))") {
return (pass);
}
if (req.url ~ "[?&](utm_source|utm_medium|utm_campaign|gclid|cx|ie|cof|siteurl)=") {
set req.url = regsuball(req.url, "(?:(\?)?|&)(?:utm_source|utm_medium|utm_campaign|gclid|cx|ie|cof|siteurl)=[^&]+", "\1");
set req.url = regsuball(req.url, "(?:(\?)&|\?$)", "\1");
}
if (true && req.url ~ "[?&](utm_source|utm_medium|utm_campaign|utm_content|utm_term|gclid|cx|ie|cof|siteurl)=") {
set req.url = regsuball(req.url, "(?:(\?)?|&)(?:utm_source|utm_medium|utm_campaign|utm_content|utm_term|gclid|cx|ie|cof|siteurl)=[^&]+", "\1");
set req.url = regsuball(req.url, "(?:(\?)&|\?$)", "\1");
}
if(false) {
set req.http.X-Varnish-Cache-Url = req.url;
set req.url = req.http.X-Varnish-Origin-Url;
unset req.http.X-Varnish-Origin-Url;
}
return (hash);
}

