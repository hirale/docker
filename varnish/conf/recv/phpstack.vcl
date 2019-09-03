#Purging
if (req.method == "PURGE") {
                if (!client.ip ~ purge) {
return(synth(405, "This IP is not allowed to send PURGE requests."));
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

#Removing Cookies from static objects
 if (req.url ~ "\.(png|gif|jpg|ico|jpeg|swf|pdf|js|css)$") {
    unset req.http.cookie;
  }
 if (req.http.Authorization || req.http.Authenticate)
        {
        set req.backend_hint = admin;
        return (pass);
        }
#Do not compress objects that are already compressed
if (req.http.Accept-Encoding) {
    if (req.url ~ "\.(gif|jpg|jpeg|swf|flv|mp3|mp4|pdf|png|gz|tgz|tbz|bz2)(\?.*|)$") {
      unset req.http.Accept-Encoding;
    } elsif (req.http.Accept-Encoding ~ "gzip") {
      set req.http.Accept-Encoding = "gzip";
    } elsif (req.http.Accept-Encoding ~ "deflate") {
      set req.http.Accept-Encoding = "deflate";
    } else {
      unset req.http.Accept-Encoding;
    }
}
