       # set minimum timeouts to auto-discard stored objects
#       set beresp.prefetch = -30s;
        set beresp.grace = 120s;
 
        if (beresp.ttl < 4h) {
          set beresp.ttl = 4h;}
 
        if (!beresp.ttl > 0s) {
                set beresp.uncacheable = true;
        } 
 
        if (beresp.http.Set-Cookie) {
		set beresp.uncacheable = true;
	} 
 
#       if (beresp.http.Cache-Control ~ "(private|no-cache|no-store)") 
#           {return(hit_for_pass);}
 
        if (bereq.http.Authorization && !beresp.http.Cache-Control ~ "public") {
		set beresp.uncacheable = true;
	}
