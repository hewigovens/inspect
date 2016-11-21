//
//  nghttp2client.h
//  Inspect
//
//  Created by hewig on 11/20/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

#ifndef nghttp2client_h
#define nghttp2client_h

#include <nghttp2/nghttp2.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/conf.h>

struct Connection {
    SSL *ssl;
    nghttp2_session *session;
    /* WANT_READ if SSL/TLS connection needs more input; or WANT_WRITE
     if it needs more output; or IO_NONE. This is necessary because
     SSL/TLS re-negotiation is possible at any time. nghttp2 API
     offers similar functions like nghttp2_session_want_read() and
     nghttp2_session_want_write() but they do not take into account
     SSL/TSL connection. */
    int want_io;
};

struct Request {
    char *host;
    /* In this program, path contains query component as well. */
    char *path;
    /* This is the concatenation of host and port with ":" in
     between. */
    char *hostport;
    /* Stream ID for this request. */
    int32_t stream_id;
    uint16_t port;
};

struct URI {
    const char *host;
    /* In this program, path contains query component as well. */
    const char *path;
    size_t pathlen;
    const char *hostport;
    size_t hostlen;
    size_t hostportlen;
    uint16_t port;
};

int probe(const char *url);

#endif /* nghttp2client_h */
