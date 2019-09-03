# Normalize the header, unset the port (in case you're testing this on various TCP ports)
set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");
# Allow purging from ACL
# Post requests will not be cached
if (req.http.Authorization || req.method == "POST") {
return (pipe);
}
# --- Wordpress specific configuration
# Did not cache the RSS feed
if (req.url ~ "/feed") {
return (pass);
}
# Blitz hack
if (req.url ~ "/mu-.*") {
return (pass);
}
# Did not cache the admin and login pages
if (req.url ~ "/wp-(login|admin)") {
return (pass);
}
# Do not cache the WooCommerce pages
### REMOVE IT IF YOU DO NOT USE WOOCOMMERCE ###
if (req.url ~ "/(cart|my-account|checkout|addons|\?add-to-cart=|add-to-cart)") {
return (pipe);
}
# Remove the "has_js" cookie
set req.http.Cookie = regsuball(req.http.Cookie, "has_js=[^;]+(; )?", "");
set req.http.Cookie = regsuball(req.http.Cookie, "__distillery=[^;]+(; )?", "");
# Remove any Google Analytics based cookies
set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");
set req.http.Cookie = regsuball(req.http.Cookie, "_ga=[^;]+(; )?", "");
set req.http.Cookie = regsuball(req.http.Cookie, "_gat=[^;]+(; )?", "");
set req.http.Cookie = regsuball(req.http.Cookie, "PHPSESSID=[^;]+(; )?", "");
# Remove the Quant Capital cookies (added by some plugin, all __qca)
set req.http.Cookie = regsuball(req.http.Cookie, "__qc.=[^;]+(; )?", "");
# Remove the wp-settings-1 cookie
set req.http.Cookie = regsuball(req.http.Cookie, "wp-settings-1=[^;]+(; )?", "");
# Remove the wp-settings-time-1 cookie
set req.http.Cookie = regsuball(req.http.Cookie, "wp-settings-time-1=[^;]+(; )?", "");
# Remove the wp test cookie
set req.http.Cookie = regsuball(req.http.Cookie, "wordpress_test_cookie=[^;]+(; )?", "");
# Are there cookies left with only spaces or that are empty?
if (req.http.cookie ~ "^ *$") {
unset req.http.cookie;
}
# Cache the following files extensions
if (req.url ~ "\.(css|js|png|gif|jp(e)?g|swf|ico)") {
unset req.http.cookie;
}
# Normalize Accept-Encoding header and compression
# https://www.varnish-cache.org/docs/3.0/tutorial/vary.html
if (req.http.Accept-Encoding) {
# Do no compress compressed files...
if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
unset req.http.Accept-Encoding;
} elsif (req.http.Accept-Encoding ~ "gzip") {
set req.http.Accept-Encoding = "gzip";
} elsif (req.http.Accept-Encoding ~ "deflate") {
set req.http.Accept-Encoding = "deflate";
} else {
unset req.http.Accept-Encoding;
}
}
# Check the cookies for wordpress-specific items
if (req.http.Cookie ~ "wordpress_" || req.http.Cookie ~ "comment_") {
	return (pass);
}
if (!req.http.cookie) {
unset req.http.cookie;
}
# --- End of Wordpress specific configuration
# Did not cache HTTP authentication and HTTP Cookie
if (req.http.Authorization || req.http.Cookie) {
# Not cacheable by default
return (pass);
}

#Purging
if (req.method == "URLPURGE") {
        if (!client.ip ~ purge) {
           return(synth(405, "This IP is not allowed to send PURGE requests."));
        }
        return (purge);
}
if (req.method == "PURGE") {
                if (!client.ip ~ purge) {
			return(synth(405, "Not allowed."));
                }
                ban("req.http.host ~ " + req.http.host);
                return (purge);
        }
#Baning
if (req.method == "BAN") {
                if (!client.ip ~ purge) {
			return(synth(405, "This IP is not allowed to send PURGE requests."));
                }
                ban("req.http.host == " + req.http.host +
                      "&& req.url == " + req.url);
		return(synth(200, "Ban added"));

        }

  if (req.http.Accept-Encoding) {
    if (req.url ~ "\.(gif|jpg|jpeg|swf|flv|mp3|mp4|pdf|ico|png|gz|tgz|bz2)(\?.*|)$") {
      unset req.http.Accept-Encoding;
    } elsif (req.http.Accept-Encoding ~ "gzip") {
      set req.http.Accept-Encoding = "gzip";
    } elsif (req.http.Accept-Encoding ~ "deflate") {
      set req.http.Accept-Encoding = "deflate";
    } else {
      unset req.http.Accept-Encoding;
    }
  }
  if (req.url ~ "\.(gif|jpg|jpeg|swf|css|js|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
    unset req.http.cookie;
    set req.url = regsub(req.url, "\?.*$", "");
  }
  if (req.url ~ "\?(utm_(campaign|medium|source|term)|adParams|client|cx|eid|fbid|feed|ref(id|src)?|v(er|iew))=") {
    set req.url = regsub(req.url, "\?.*$", "");
  }
  if (req.http.cookie) {
    if (req.http.cookie ~ "(wordpress_|wp-settings-)") {
	set req.backend_hint = admin;
      return(pass);
    } else {
      unset req.http.cookie;
    }
  }
