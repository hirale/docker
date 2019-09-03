        ##hiding some headers added by Varnish.
        unset resp.http.X-Varnish;
        ##Hiding people to see we are using Varnish.
        unset resp.http.Via;
        ## Hiding the X-Powered-By headers and PHP version info in headers.
        unset resp.http.X-Powered-By;

        #Set Expire time
        ##Check if object is served from Cache or Not

        if (obj.hits > 0) {
                set resp.http.X-Cache = "HIT";
        } else {
                set resp.http.X-Cache = "MISS";
        }

        if (resp.http.magicmarker) {
        ##/* Remove the magic marker */
                unset resp.http.magicmarker;
        ##By definition we have a fresh object */
                set resp.http.age = "0";
        }

