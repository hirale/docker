vcl 4.0;
// Nexcess.net Turpentine Extension for Magento
// Copyright (C) 2012  Nexcess.net L.L.C.
//
// This program is free software, you can redistribute it or modify
// it under the terms of the GNU General Public License (GPL) as published
// by the free software foundation, either version 2 of the license, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but without any warranty, without even the implied warranty of
// merchantability or fitness for a particular purpose. See the
// GNU General Public License (GPL) for more details.

// Nexcessnet_Turpentine Varnish v4 VCL Template
// The Varnish Configuration Language (VCL)
// https://www.varnish-software.com/developers/tutorials/varnish-configuration-language-vcl/

////////////////////////////////////////////////////////////
// Custom C Code

C{
    #include <stdlib.h>
    #include <stdio.h>
    #include <time.h>
    #include <pthread.h>
    static pthread_mutex_t lrand_mutex = PTHREAD_MUTEX_INITIALIZER;
    void generate_uuid(char* buf) {
        pthread_mutex_lock(&lrand_mutex);
        long a = lrand48();
        long b = lrand48();
        long c = lrand48();
        long d = lrand48();
        pthread_mutex_unlock(&lrand_mutex);
        // SID must match this regex for Kount compat /^\w{1,32}$/
        sprintf(buf, "om_frontend=%08lx%04lx%04lx%04lx%04lx%08lx",
            a,
            b & 0xffff,
            (b & ((long)0x0fff0000) >> 16) | 0x4000,
            (c & 0x0fff) | 0x8000,
            (c & (long)0xffff0000) >> 16,
            d
        );
        return;
    }
}C

////////////////////////////////////////////////////////////
// Imports

import std;
import directors;

////////////////////////////////////////////////////////////
// Custom VCL Logic - Top



////////////////////////////////////////////////////////////
// Backends

backend default {
    .host = "pagespeed";
    .port = "80";
   .first_byte_timeout = 300s;
   .between_bytes_timeout = 300s;
}


backend admin {
    .host = "pagespeed";
    .port = "80";
   .first_byte_timeout = 21600s;
   .between_bytes_timeout = 21600s;
}


////////////////////////////////////////////////////////////
// ACLs

acl crawler_acl {
    "127.0.0.1";
    "172.20.0.2";
    "172.20.0.12";
}

acl debug_acl {
    
}

////////////////////////////////////////////////////////////
// Custom Subroutines

/* -- REMOVED

sub generate_session {
    // generate a UUID and add `om_frontend=$UUID` to the Cookie header, or use SID from SID URL param
    if (req.url ~ ".*[&?]SID=([^&]+).*") {
        set req.http.X-Varnish-Faked-Session = regsub(req.url, ".*[&?]SID=([^&]+).*", "om_frontend=\1");
    }
    else {
        C{
            char uuid_buf [50];
            generate_uuid(uuid_buf);
            static const struct gethdr_s VGC_HDR_REQ_VARNISH_FAKED_SESSION = { HDR_REQ, "\030X-Varnish-Faked-Session:" };
            VRT_SetHdr(ctx,
                &VGC_HDR_REQ_VARNISH_FAKED_SESSION,
                uuid_buf,
                vrt_magic_string_end
            );
        }C
    }
    if (req.http.Cookie) {
        // client sent us cookies, just not a om_frontend cookie
        // try not to blow away the extra cookies
        std.collect(req.http.Cookie);
        set req.http.Cookie = req.http.X-Varnish-Faked-Session + "; " + req.http.Cookie;
    }
    else {
        set req.http.Cookie = req.http.X-Varnish-Faked-Session;
    }
}

sub generate_session_expires {
    // sets X-Varnish-Cookie-Expires to now + esi_private_ttl in format: Tue, 19-Feb-2013 00:14:27 GMT
    // this isn't threadsafe but it shouldn't matter in this case
    C{
        time_t now = time(NULL);
        struct tm now_tm = *gmtime(&now);
        now_tm.tm_sec += 86400;
        mktime(&now_tm);
        char date_buf [50];
        strftime(date_buf, sizeof(date_buf)-1, "%a, %d-%b-%Y %H:%M:%S %Z", &now_tm);
        static const struct gethdr_s VGC_HDR_RESP_COOKIE_EXPIRES = { HDR_RESP, "\031X-Varnish-Cookie-Expires:"};
        VRT_SetHdr(ctx,
            &VGC_HDR_RESP_COOKIE_EXPIRES,
            date_buf,
            vrt_magic_string_end
        );
    }C
}

-- */

////////////////////////////////////////////////////////////
// Varnish Subroutines

sub vcl_init {
    
}

sub vcl_recv {

    // Fix ESI URLs broken by Mod_PageSpeed
    if (req.url ~ "https?: ") {
        set req.http.Host = regsub(req.url, "^.*https?: ([\w\.\-]+(\s?\:[0-9]+)?).*$", "\1");
        set req.url = regsub(req.url, "^.*https?: ([\w\.\-]+(\s?\:[0-9]*)?)", "");
        set req.url = regsuball(req.url, " ", "/");
    }

    // ESI request should not be included in the profile.
    // Instead you should profile them separately, each one
    // in their dedicated profile.
    // Removing the Blackfire header avoids to trigger the profiling.
    // Not returning let it go trough your usual workflow as a regular
    // ESI request without distinction.
    if (req.esi_level > 0) {
        unset req.http.X-Blackfire-Query;
    }

    // If it's a Blackfire query and the client is authorized, just pass directly to the application.
    if (req.http.X-Blackfire-Query) {
        return (pass);
    }

    if (req.url ~ "^(/media/|/skin/|/js/|/)(?:(?:index|litespeed)\.php/)?xrankseo") {
        set req.backend_hint = admin;
    }
    else {
        
    }

    
    
    

    // We only deal with GET and HEAD by default
    // we test this here instead of inside the url base regex section
    // so we can disable caching for the entire site if needed
    if (!true || req.http.Authorization ||
        req.method !~ "^(GET|HEAD|OPTIONS)$" ||
        req.http.Cookie ~ "varnish_bypass=1") {
        return (pipe);
    }

    // save the unmodified url
    if (false) {
        set req.http.X-Varnish-Origin-Url = req.url;
    }

    // remove double slashes from the URL, for higher cache hit rate
    set req.url = regsuball(req.url, "(.*)//+(.*)", "\1/\2");

    if (req.http.Accept-Encoding) {
        if (req.http.Accept-Encoding ~ "\*|gzip") {
            set req.http.Accept-Encoding = "gzip";
        } else if (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
        } else {
            # unknown algorithm
            unset req.http.Accept-Encoding;
        }
    }

    
    

    // check if the request is for part of Magento
    if (req.url ~ "^(/media/|/skin/|/js/|/)(?:(?:index|litespeed)\.php/)?") {

        // set this so Turpentine can see the request passed through Varnish
        set req.http.X-Turpentine-Secret-Handshake = "1";

        // use the special admin backend and pipe if it's for the admin section
        if (req.url ~ "^(/media/|/skin/|/js/|/)(?:(?:index|litespeed)\.php/)?xrankseo") {
            return (pipe);
        }
        if (req.http.Cookie ~ "\bcurrency=") {
            set req.http.X-Varnish-Currency = regsub(req.http.Cookie, ".*\bcurrency=([^;]*).*", "\1");
        }
        if (req.http.Cookie ~ "\bstore=") {
            set req.http.X-Varnish-Store = regsub(req.http.Cookie, ".*\bstore=([^;]*).*", "\1");
        }

        // looks like an ESI request, add some extra vars for further processing
        if (req.url ~ "/turpentine/esi/get(?:Block|FormKey)/") {
            set req.http.X-Varnish-Esi-Method = regsub(req.url, ".*/method/(\w+)/.*", "\1");
            set req.http.X-Varnish-Esi-Access = regsub(req.url, ".*/access/(\w+)/.*", "\1");
            // throw a forbidden error if debugging is off and a esi block is
            // requested by the user (does not apply to ajax blocks)
            if (req.http.X-Varnish-Esi-Method == "esi" && req.esi_level == 0 && !(false || client.ip ~ debug_acl)) {
                return (synth(403, "External ESI requests are not allowed"));
            }
        }

        

        // no om_frontend cookie was sent to us AND this is not an ESI or AJAX call
        if (req.http.Cookie !~ "om_frontend=" && !req.http.X-Varnish-Esi-Method) {
            if (client.ip ~ crawler_acl || req.http.User-Agent ~ "^(?:ApacheBench/.*|.*Googlebot.*|.*APIs-Google.*|.*Mediapartners-Google.*|.*AdsBot-Google.*|JoeDog/.*|.*Siege/.*|magespeedtest\.com|Nexcessnet_Turpentine/.*|.*PTST.*|.*bingbot.*|.*msnbot.*|.*Baiduspider.*)$") {
                // it's a crawler, give it a fake cookie
                set req.http.Cookie = "om_frontend=crawler-session";
            }
            else {
                // it's a real user, make up a new session for them
                return (pipe);
            }
        }
        if (true && req.url ~ ".*\.(?:css|js|jpe?g|png|gif|ico|swf)(?=\?|&|$)") {
            // don't need cookies for static assets
            unset req.http.Cookie;
            unset req.http.X-Varnish-Faked-Session;
            set req.http.X-Varnish-Static = 1;
            return (hash);
        }
        // this doesn't need a enable_url_excludes because we can be reasonably
        // certain that cron.php at least will always be in it, so it will
        // never be empty
        if (req.url ~ "^(/media/|/skin/|/js/|/)(?:(?:index|litespeed)\.php/)?(?:xrankseo|api|cron\.php)" ||
                // user switched stores. we pipe this instead of passing below because
                // switching stores doesn't redirect (302), just acts like a link to
                // another page (200) so the Set-Cookie header would be removed
                req.url ~ "\?.*__from_store=") {
            return (pipe);
        }
        if (true && req.url ~ "(?:[?&](?:__SID|XDEBUG_PROFILE)(?=[&=]|$))") {
            // TODO: should this be pass or pipe?
            return (pass);
        }

        // Strip out Google related parameters
        if (req.url ~ "[?&](utm_source|utm_medium|utm_campaign|gclid|cx|ie|cof|siteurl)=") {
            set req.url = regsuball(req.url, "(?:(\?)?|&)(?:utm_source|utm_medium|utm_campaign|gclid|cx|ie|cof|siteurl)=[^&]+", "\1");
            set req.url = regsuball(req.url, "(?:(\?)&|\?$)", "\1");
        }

        // Strip out Ignored GET parameters
        if (true && req.url ~ "[?&](utm_source|utm_medium|utm_campaign|utm_content|utm_term|gclid|cx|ie|cof|siteurl)=") {
            set req.url = regsuball(req.url, "(?:(\?)?|&)(?:utm_source|utm_medium|utm_campaign|utm_content|utm_term|gclid|cx|ie|cof|siteurl)=[^&]+", "\1");
            set req.url = regsuball(req.url, "(?:(\?)&|\?$)", "\1");
        }

        if (false) {
            set req.http.X-Varnish-Cache-Url = req.url;
            set req.url = req.http.X-Varnish-Origin-Url;
            unset req.http.X-Varnish-Origin-Url;
        }

        // everything else checks out, try and pull from the cache
        return (hash);
    }
    // else it's not part of Magento so do default handling (doesn't help
    // things underneath Magento but we can't detect that)
    else {
        // return 444;
        unset req.http.connection;
        return (pipe);
    }
}

sub vcl_pipe {
    // since we're not going to do any stuff to the response we pretend the
    // request didn't pass through Varnish
    unset bereq.http.X-Turpentine-Secret-Handshake;
    set bereq.http.Connection = "close";
}

sub vcl_hash {

    std.log("vcl_hash start");

    // For static files we keep the hash simple and don't add the domain.
    // This saves memory when a static file is used on multiple domains.
    if (true && req.http.X-Varnish-Static) {
        std.log("hash_data static file - req.url: " + req.url);
        hash_data(req.url);
        if (req.http.Accept-Encoding) {
            // make sure we give back the right encoding
            std.log("hash_data static file - Accept-Encoding: " + req.http.Accept-Encoding);
            hash_data(req.http.Accept-Encoding);
        }
        std.log("vcl_hash end return lookup");
        return (lookup);
    }

    if (false && req.http.X-Varnish-Cache-Url) {
        hash_data(req.http.X-Varnish-Cache-Url);
        std.log("hash_data - X-Varnish-Cache-Url: " + req.http.X-Varnish-Cache-Url);
    }
    else {
        hash_data(req.url);
        std.log("hash_data - req.url: " + req.url);
    }

    if (req.http.Host) {
        hash_data(req.http.Host);
        std.log("hash_data - req.http.Host: " + req.http.Host);
    }
    else {
        hash_data(server.ip);
    }

    std.log("hash_data - req.http.Ssl-Offloaded: " + req.http.Ssl-Offloaded);
    hash_data(req.http.Ssl-Offloaded);

    if (req.http.X-Normalized-User-Agent) {
        hash_data(req.http.X-Normalized-User-Agent);
        std.log("hash_data - req.http.X-Normalized-User-Agent: " + req.http.X-Normalized-User-Agent);
    }
    if (req.http.Accept-Encoding) {
        // make sure we give back the right encoding
        hash_data(req.http.Accept-Encoding);
        std.log("hash_data - req.http.Accept-Encoding: " + req.http.Accept-Encoding);
    }
    if (req.http.X-Varnish-Store || req.http.X-Varnish-Currency) {
        // make sure data is for the right store and currency based on the *store*
        // and *currency* cookies
        hash_data("s=" + req.http.X-Varnish-Store + "&c=" + req.http.X-Varnish-Currency);
        std.log("hash_data - Store and Currency: " + "s=" + req.http.X-Varnish-Store + "&c=" + req.http.X-Varnish-Currency);
    }
    if (req.http.X-Varnish-Esi-Access == "private" && req.http.Cookie ~ "om_frontend=") {
        std.log("hash_data - om_frontend cookie: " + regsub(req.http.Cookie, "^.*?om_frontend=([^;]*);*.*$", "\1"));
        hash_data(regsub(req.http.Cookie, "^.*?om_frontend=([^;]*);*.*$", "\1"));
        hash_data(client.ip);
hash_data(req.http.Via);
hash_data(req.http.X-Forwarded-For);
hash_data(req.http.User-Agent);

    }
    if (req.http.X-Varnish-Esi-Access == "customer_group" && req.http.Cookie ~ "customer_group=") {
        hash_data(regsub(req.http.Cookie, "^.*?customer_group=([^;]*);*.*$", "\1"));
    }
    std.log("vcl_hash end return lookup");
    return (lookup);
}

sub vcl_backend_response {

    // set the grace period
    set beresp.grace = 15s;

    // Store the URL in the response object, to be able to do lurker friendly bans later
    set beresp.http.X-Varnish-Host = bereq.http.host;
    set beresp.http.X-Varnish-URL = bereq.url;

    // if it's part of Magento
    if (bereq.url ~ "^(/media/|/skin/|/js/|/)(?:(?:index|litespeed)\.php/)?") {
        // we handle the Vary stuff ourselves for now, we'll want to actually
        // use this eventually for compatibility with downstream proxies
        // TODO: only remove the User-Agent field from this if it exists
        unset beresp.http.Vary;
        // we pretty much always want to do this
        set beresp.do_gzip = true;

        if (beresp.status != 200 && beresp.status != 404) {
            // pass anything that isn't a 200 or 404
            set beresp.ttl = 15s;
            set beresp.uncacheable = true;
            return (deliver);
        }
        else {
            // if Magento sent us a Set-Cookie header, we'll put it somewhere
            // else for now
            if (beresp.http.Set-Cookie) {
                set beresp.http.X-Varnish-Set-Cookie = beresp.http.Set-Cookie;
                unset beresp.http.Set-Cookie;
            }

            // we'll set our own cache headers if we need them
            // we'll override the "Cache-Control" header if needed
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
                set beresp.http.Cache-Control = "no-store, no-cache, must-revalidate";
                return (deliver);
            }
            else {
                if (true && bereq.url ~ ".*\.(?:css|js|jpe?g|png|gif|ico|swf)(?=\?|&|$)") {
                    // it's a static asset
                    set beresp.ttl = 28800s;
                    set beresp.http.Cache-Control = "max-age=28800";
                }
                else if (bereq.http.X-Varnish-Esi-Method) {
                    // it's a ESI request
                    if (bereq.http.X-Varnish-Esi-Access == "private" && bereq.http.Cookie ~ "om_frontend=") {
                        // set this header so we can ban by session from Turpentine
                        set beresp.http.X-Varnish-Session = regsub(bereq.http.Cookie, "^.*?om_frontend=([^;]*);*.*$", "\1");
                    }
                    if (bereq.http.X-Varnish-Esi-Method == "ajax" && bereq.http.X-Varnish-Esi-Access == "public") {
                        set beresp.http.Cache-Control = "max-age=" + regsub(bereq.url, ".*/ttl/(\d+)/.*", "\1");
                    }
                    set beresp.ttl = std.duration(
                        regsub(
                            bereq.url, ".*/ttl/(\d+)/.*", "\1s"),
                        300s);
                    if (beresp.ttl == 0s) {
                        // this is probably faster than bothering with 0 ttl
                        // cache objects
                        set beresp.ttl = 15s;
                        set beresp.uncacheable = true;
                        set beresp.http.Cache-Control = "no-store, no-cache, must-revalidate";
                        return (deliver);
                    }
                }
                else {
                    set beresp.ttl = 3600s;
                }
            }
        }
        // we've done what we need to, send to the client
        return (deliver);
    }
    // else it's not part of Magento so use the default Varnish handling
}



sub vcl_deliver {
    if (req.http.X-Varnish-Faked-Session) {
        // need to set the set-cookie header since we just made it out of thin air
        # call generate_session_expires
        set resp.http.Set-Cookie = req.http.X-Varnish-Faked-Session + "; expires=" + resp.http.X-Varnish-Cookie-Expires + "; path=/";
        if (req.http.Host) {
            if (req.http.User-Agent ~ "^(?:ApacheBench/.*|.*Googlebot.*|.*APIs-Google.*|.*Mediapartners-Google.*|.*AdsBot-Google.*|JoeDog/.*|.*Siege/.*|magespeedtest\.com|Nexcessnet_Turpentine/.*|.*PTST.*|.*bingbot.*|.*msnbot.*|.*Baiduspider.*)$") {
                // it's a crawler, no need to share cookies
                set resp.http.Set-Cookie = resp.http.Set-Cookie +
                "; domain=" + regsub(req.http.Host, ":\d+$", "");
            }
            else {
                // it's a real user, allow sharing of cookies between stores
                if (req.http.Host ~ "" && "" ~ "..") {
                    set resp.http.Set-Cookie = resp.http.Set-Cookie + "; domain=";
                }
                else {
                    set resp.http.X-Varnish-CookieDomain = regsub(req.http.Host, ":\d+$", "");
                    
                    set resp.http.Set-Cookie = resp.http.Set-Cookie + "; domain=" + resp.http.X-Varnish-CookieDomain;
                }
            }
        }
        set resp.http.Set-Cookie = resp.http.Set-Cookie + "; httponly";
        unset resp.http.X-Varnish-Cookie-Expires;
    }
    if (req.http.X-Varnish-Esi-Method == "ajax" && req.http.X-Varnish-Esi-Access == "private") {
        set resp.http.Cache-Control = "no-cache";
    }
    if (false || client.ip ~ debug_acl) {
        // debugging is on, give some extra info
        set resp.http.X-Varnish-Hits = obj.hits;
        set resp.http.X-Varnish-Esi-Method = req.http.X-Varnish-Esi-Method;
        set resp.http.X-Varnish-Esi-Access = req.http.X-Varnish-Esi-Access;
        set resp.http.X-Varnish-Currency = req.http.X-Varnish-Currency;
        set resp.http.X-Varnish-Store = req.http.X-Varnish-Store;
    }
    else {
        // remove Varnish fingerprints
        unset resp.http.X-Varnish;
        unset resp.http.Via;
        unset resp.http.X-Powered-By;
        unset resp.http.Server;
        unset resp.http.X-Turpentine-Cache;
        unset resp.http.X-Turpentine-Esi;
        unset resp.http.X-Turpentine-Flush-Events;
        unset resp.http.X-Turpentine-Block;
        unset resp.http.X-Varnish-Session;
        unset resp.http.X-Varnish-Host;
        unset resp.http.X-Varnish-URL;
        unset resp.http.X-Varnish-CookieDomain;
        // this header indicates the session that originally generated a cached
        // page. it *must* not be sent to a client in production with lax
        // session validation or that session can be hijacked
        unset resp.http.X-Varnish-Set-Cookie;
    }
}

////////////////////////////////////////////////////////////
// Custom VCL Logic - Bottom


