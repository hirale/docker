#Uncomment Lines below to disable varnish cache on https 

#   if (req.http.X-Forwarded-Proto ~ "(?i)https") {
#      if (req.http.X-Application ~ "(?i)woocommerce") {
#           return(pipe);
#        } else {
#           return(pass);
#      }
#   }

