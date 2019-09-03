        if (bereq.url ~ "\.(png|gif|jpg|ico|jpeg|swf|js|css|pdf)$") {
        ##Remove Expires from backend, it's not long enough */
        unset beresp.http.expires;
        ##Set the clients TTL on this object */
        set beresp.http.cache-control = "max-age=1440";
        ##Set how long Varnish will keep it */
        set beresp.ttl = 1d;
        ##marker for vcl_deliver to reset Age: */
        set beresp.http.magicmarker = "1";
        #Setexpires headers
        set beresp.http.expires="1440";
        }

