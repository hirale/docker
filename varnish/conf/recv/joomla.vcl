# Handle cache purges/bans
        if (req.method == "PURGE") {
                if (client.ip !~ purge) {
                        return(synth(401, "Not allowed to purge"));
                }
                ban("obj.http.x-url ~ " + req.url);
                return(synth(200, "Purged " + req.url));
        }


# pass mode can't handle POST (yet)
        if (req.method == "POST") {
                return(pipe);
        }

# Never cache these paths
# More URLs may go here, if needed
        if (req.url ~ "/administrator/" || req.url ~ "(ms_http_purge|media_upload)")
        {
                return(pipe);
        }

# Cache static files - add more file extensions if needed
        if (req.url ~ "\.(png|jpg|gif|css|js|swf|flv|ico|xml|txt|pdf|doc|woff|eot|mp[34]|svg|svgz|map)$"
# Force caching certain URLs (you will also need to add them in vcl_fetch below)
#               || req.url ~ "/blog/"
                ) {
                unset req.http.cookie;
        }

# com_fpss support - delete if not using this extension
        if(req.url ~ "media/com_fpss/src/") {
                set req.url = regsub(req.url, "^([^\?]+)\?t.*$", "\1");
                unset req.http.cookie;
        }


# Normalize encoding headers
        if (req.http.Accept-Encoding) {
                # Don't compress already-compressed files
                if (req.url ~ "\.(jpg|jpeg|png|gif|zip|gz|svgz|tgz|bz2|tbz|mp3|ogg)$") {
                        unset req.http.Accept-Encoding;
#               } elsif (req.http.Accept-Encoding ~ "sdch") {
#                       set req.http.Accept-Encoding = "sdch";
                } elsif (req.http.Accept-Encoding ~ "gzip") {
                        set req.http.Accept-Encoding = "gzip";
                } elsif (req.http.Accept-Encoding ~ "deflate" && req.http.user-agent !~ "Internet Explorer") {
                        set req.http.Accept-Encoding = "deflate";
                } else {
                        # Send uncompressed content to everyone else
                        unset req.http.Accept-Encoding;
                }
        }

# Force lookup even when some cookies are present
        if (req.method == "GET")
        {
                if(!req.http.cookie) {
                        return(hash);
                }

# Remove analytics cookies - they're no use for the server anyway
                if (req.http.Cookie) {
                        # Google Analytics and Piwik
                        set req.http.Cookie = regsuball(req.http.Cookie, "(^|; ) *(__utm.|_pk_[^=]+)=[^;]+;? *", "\1");
                        # Cloudflare
                        set req.http.Cookie = regsuball(req.http.Cookie, "(^|; ) *__cfduid=[^;]+;? *", "\1");
                        set req.http.Cookie = regsuball(req.http.Cookie, "(^|; ) *cf_use_ob=[^;]+;? *", "\1");
                        if (req.http.Cookie == "") {
                                unset req.http.Cookie;
                        }
                }

# Unset all cookies unless a Joomla session cookie is present
                if (req.method == "GET" && !(req.http.cookie ~ "[a-z0-9]{32}=[a-z0-9]+"))
                {
                        unset req.http.cookie;
                        return(hash);
                }
                else
                {
                        return(pipe);
                }
        }

        return(pipe);
