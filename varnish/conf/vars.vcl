#
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
sprintf(buf, "frontend=%08lx%04lx%04lx%04lx%04lx%08lx",
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
/* -- REMOVED
sub generate_session {
if (req.url ~ ".*[&?]SID=([^&]+).*") {
set req.http.X-Varnish-Faked-Session = regsub(
req.url, ".*[&?]SID=([^&]+).*", "frontend=\1");
} else {
C{
char uuid_buf [50];
generate_uuid(uuid_buf);
VRT_SetHdr(sp, HDR_REQ,
"\030X-Varnish-Faked-Session:",
uuid_buf,
vrt_magic_string_end
);
}C
}
if (req.http.Cookie) {
std.collect(req.http.Cookie);
set req.http.Cookie = req.http.X-Varnish-Faked-Session +
"; " + req.http.Cookie;
} else {
set req.http.Cookie = req.http.X-Varnish-Faked-Session;
}
}
sub generate_session_expires {
C{
time_t now = time(NULL);
struct tm now_tm = *gmtime(&now);
now_tm.tm_sec += 3600;
mktime(&now_tm);
char date_buf [50];
strftime(date_buf, sizeof(date_buf)-1, "%a, %d-%b-%Y %H:%M:%S %Z", &now_tm);
VRT_SetHdr(sp, HDR_RESP,
"\031X-Varnish-Cookie-Expires:",
date_buf,
vrt_magic_string_end
);
}C
}
-- */

