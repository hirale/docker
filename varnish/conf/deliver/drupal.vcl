  if (obj.hits > 0) {
    set resp.http.X-Varnish-Cache = "HIT";
  }
  else {
    set resp.http.X-Varnish-Cache = "MISS";
  }
  unset resp.http.X-Drupal-Cache;
  unset resp.http.X-Generator;
