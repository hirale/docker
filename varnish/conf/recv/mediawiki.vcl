#
# Serve objects up to 2 minutes past their expiry if the backend is slow to respond.
#        set req.grace = 120s;
 
# This uses the ACL action called "purge". Basically if a request to
# PURGE the cache comes from anywhere other than localhost, ignore it.
        if (req.method == "PURGE") 
            {if (!client.ip ~ purge)
                {return(synth(405, "This IP is not allowed to send PURGE requests."));}
                ban("req.http.host == " + req.http.host +
                      " && req.url == " + req.url);
		return(synth(200, "Ban added"));
	    return (purge); 
		}
# Pass any requests that Varnish does not understand straight to the backend.
        if (req.method != "GET" && req.method != "HEAD" &&
            req.method != "PUT" && req.method != "POST" &&
            req.method != "TRACE" && req.method != "OPTIONS" &&
            req.method != "DELETE") {
		return(pipe);
	} #     /* Non-RFC2616 or CONNECT which is weird. */
 
# Pass anything other than GET and HEAD directly.
        if (req.method != "GET" && req.method != "HEAD")
           {return(pass);}   #   /* We only deal with GET and HEAD by default */
 
# Pass requests from logged-in users directly.
        if (req.http.Authorization || req.http.Cookie)
           {return(pass);}    #  /* Not cacheable by default */

# Pass any requests with the "If-None-Match" header directly.
        if (req.http.If-None-Match)
           {return(pass);}

# Force lookup if the request is a no-cache request from the client.
#        if (req.http.Cache-Control ~ "no-cache")
#           {ban_url(req.url);}
 
# normalize Accept-Encoding to reduce vary
        if (req.http.Accept-Encoding) {
          if (req.http.User-Agent ~ "MSIE 6") {
            unset req.http.Accept-Encoding;
          } elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
          } elsif (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
          } else {
            unset req.http.Accept-Encoding;
          }
        }
 
        return(hash);
