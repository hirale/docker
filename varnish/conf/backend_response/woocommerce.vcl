  if (bereq.url ~ "wp-(login|admin)" || bereq.url ~ "preview=true" || bereq.url ~ "xmlrpc.php") {
	set beresp.uncacheable = true;
	return (deliver);
  }
  if (beresp.http.set-cookie ~ "(wordpress_|wp-settings-)") {
	set beresp.uncacheable = true;
	return (deliver);
  }
  if ( (!(bereq.url ~ "(wp-(login|admin)|login)")) || (bereq.method == "GET") ) {
    unset beresp.http.set-cookie;
	set beresp.ttl = 4h;
  }
  if (bereq.url ~ "\.(gif|jpg|jpeg|swf|css|js|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
    set beresp.ttl = 1d;
  }
