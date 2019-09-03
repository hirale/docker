# Don't send the ban lurker variable to the outside world
        unset resp.http.x-url;

if (obj.hits > 0) {
    set resp.http.X-Varnish-Cache = "HIT";
  }
  else {
    set resp.http.X-Varnish-Cache = "MISS";
  }

