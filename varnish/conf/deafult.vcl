#Please do not perform any modification here
vcl 4.0;
include "/etc/varnish/backends.vcl";
include "/etc/varnish/vars.vcl";

import std;

acl purge {
        "php-fpm71";
        "php-fpm72";
}

sub vcl_hit {
  if (req.method == "PURGE") {    
    return(synth(200,"OK"));
  }
}

sub vcl_miss {
  if (req.method == "PURGE") {    
    return(synth(404,"Not cached"));
  }
}

sub vcl_pipe {
  if (req.http.X-Application ~ "(?i)magento") {
	if (req.http.X-Version !~ "^2") {
	    unset bereq.http.X-Turpentine-Secret-Handshake;
	    set bereq.http.Connection = "close";
	}
   }
}

#Recieve
sub vcl_recv {
   if (req.restarts == 0) {
        if (!req.http.x-forwarded-for) {
                set req.http.X-Forwarded-For = client.ip;
        }
   }
   if (req.http.X-Application ~ "(?i)varnishpass") {
                return (pipe);
   }
   include "/etc/varnish/https.vcl";
   include "/etc/varnish/additional_vcls/recv.vcl";
        if (req.http.X-Application ~ "(?i)wordpress") {
            include "/etc/varnish/recv/wordpress.vcl";
        } else if (req.http.X-Application ~ "(?i)drupal") {
            include "/etc/varnish/recv/drupal.vcl";
        } else if (req.http.X-Application ~ "(?i)woocommerce") {
            include "/etc/varnish/recv/woocommerce.vcl";
        } else if (req.http.X-Application ~ "(?i)magento") {
		if (req.http.X-Version) {
			if (req.http.X-Version ~ "^2") {
	                   include "/etc/varnish/recv/magento2.vcl";
			} else {
			   include "/etc/varnish/recv/magento.vcl";
			}
		} else {
                           include "/etc/varnish/recv/magento.vcl";
		}
        } else if (req.http.X-Application ~ "(?i)mediawiki") {
            include "/etc/varnish/recv/mediawiki.vcl";
        } else if (req.http.X-Application ~ "(?i)joomla") {
            include "/etc/varnish/recv/joomla.vcl";
        } else if (req.http.X-Application ~ "(?i)phpstack") {
                include "/etc/varnish/recv/phpstack.vcl";
        } else if (req.http.X-Application ~ "(?i)koken") {
                return (pipe);
        } else {
                include "/etc/varnish/recv/default.vcl";
        }

}
## backend_response (replacement of fetch)
sub vcl_backend_response {
   if ( beresp.status == 500 || 
        beresp.status == 502 || 
        beresp.status == 503 || 
        beresp.status == 504 || 
        beresp.status == 404 || 
        beresp.status == 403 ){
     set beresp.uncacheable = true;
   }
  include "/etc/varnish/additional_vcls/resp.vcl";
   if (bereq.http.X-Application ~ "(?i)wordpress") {
                include "/etc/varnish/backend_response/wordpress.vcl";
        } else if (bereq.http.X-Application ~ "(?i)drupal") {
                include "/etc/varnish/backend_response/drupal.vcl";
        } else if (bereq.http.X-Application ~ "(?i)woocommerce") {
                include "/etc/varnish/backend_response/woocommerce.vcl";
        } else if (bereq.http.X-Application ~ "(?i)magento") {
                if (bereq.http.X-Version) {
                        if (bereq.http.X-Version ~ "^2") {
	                           include "/etc/varnish/backend_response/magento2.vcl";
        	        } else {
                	           include "/etc/varnish/backend_response/magento.vcl";
	                }
		} else {
                    include "/etc/varnish/backend_response/magento.vcl";
		}
        } else if (bereq.http.X-Application ~ "(?i)mediawiki") {
                include "/etc/varnish/backend_response/mediawiki.vcl";
        } else if (bereq.http.X-Application ~ "(?i)joomla") {
                include "/etc/varnish/backend_response/joomla.vcl";
        } else if (bereq.http.X-Application ~ "(?i)phpstack") {
                include "/etc/varnish/backend_response/phpstack.vcl";
        } else {
        include "/etc/varnish/backend_response/default.vcl";
   }
}

## Deliver
sub vcl_deliver {
if (req.http.X-Application !~ "(?i)magento" && req.http.X-Version !~ "^2") {
        unset resp.http.X-Varnish;
}
        unset resp.http.Via;
        unset resp.http.X-Powered-By;
   	if (req.http.X-Application ~ "(?i)wordpress") {
                include "/etc/varnish/deliver/wordpress.vcl";
        } else if (req.http.X-Application ~ "(?i)drupal") {
                include "/etc/varnish/deliver/drupal.vcl";
        } else if (req.http.X-Application ~ "(?i)woocommerce") {
                include "/etc/varnish/deliver/woocommerce.vcl";
        } else if (req.http.X-Application ~ "(?i)magento") {
                if (req.http.X-Version) {
                        if (req.http.X-Version ~ "^2") {
                           include "/etc/varnish/deliver/magento2.vcl";
                        } else {
			   include "/etc/varnish/deliver/magento.vcl";
			}
                } else {
                           include "/etc/varnish/deliver/magento.vcl";
                }
        } else if (req.http.X-Application ~ "(?i)mediawiki") {
                include "/etc/varnish/deliver/mediawiki.vcl";
        } else if (req.http.X-Application ~ "(?i)joomla") {
                include "/etc/varnish/deliver/joomla.vcl";
        } else if (req.http.X-Application ~ "(?i)phpstack") {
                include "/etc/varnish/deliver/phpstack.vcl";
        } else {
        	include "/etc/varnish/deliver/default.vcl";
   }
}

sub vcl_hash {
	if (req.http.X-Application ~ "(?i)magento") {
                if (req.http.X-Version) {
                       if (req.http.X-Version ~ "^2") {
                           include "/etc/varnish/hash/magento2.vcl";
	                } else {
        	        include "/etc/varnish/hash/magento.vcl";
			}
		}
        }
        if (req.http.X-Forwarded-Proto) {
          hash_data(req.http.X-Forwarded-Proto);
        }
}

sub vcl_synth {
    set resp.http.Content-Type = "text/html; charset=utf-8";
    set resp.http.Retry-After = "5";
   return (deliver);
}


