//
//  nghttp2client.c
//  Inspect
//
//  Created by hewig on 11/20/16.
//  Copyright © 2016 fourplex. All rights reserved.
//

#include "nghttp2client.h"
#include <unistd.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <errno.h>
#include <stdio.h>
#include <dispatch/dispatch.h>

static void print_error(const char *func, const char *msg)
{
    fprintf(stderr, "FATAL: %s: %s\n", func, msg);
}

/*
 * Returns copy of string |s| with the length |len|. The returned
 * string is NULL-terminated.
 */
static char *strcopy(const char *s, size_t len) {
    char *dst;
    dst = malloc(len + 1);
    memcpy(dst, s, len);
    dst[len] = '\0';
    return dst;
}

static int parse_uri(struct URI *res, const char *uri)
{
    /* We only interested in https */
    size_t len, i, offset;
    int ipv6addr = 0;
    memset(res, 0, sizeof(struct URI));
    len = strlen(uri);
    if (len < 9 || memcmp("https://", uri, 8) != 0) {
        return -1;
    }
    offset = 8;
    res->host = res->hostport = &uri[offset];
    res->hostlen = 0;
    if (uri[offset] == '[') {
        /* IPv6 literal address */
        ++offset;
        ++res->host;
        ipv6addr = 1;
        for (i = offset; i < len; ++i) {
            if (uri[i] == ']') {
                res->hostlen = i - offset;
                offset = i + 1;
                break;
            }
        }
    } else {
        const char delims[] = ":/?#";
        for (i = offset; i < len; ++i) {
            if (strchr(delims, uri[i]) != NULL) {
                break;
            }
        }
        res->hostlen = i - offset;
        offset = i;
    }
    if (res->hostlen == 0) {
        return -1;
    }
    /* Assuming https */
    res->port = 443;
    if (offset < len) {
        if (uri[offset] == ':') {
            /* port */
            const char delims[] = "/?#";
            int port = 0;
            ++offset;
            for (i = offset; i < len; ++i) {
                if (strchr(delims, uri[i]) != NULL) {
                    break;
                }
                if ('0' <= uri[i] && uri[i] <= '9') {
                    port *= 10;
                    port += uri[i] - '0';
                    if (port > 65535) {
                        return -1;
                    }
                } else {
                    return -1;
                }
            }
            if (port == 0) {
                return -1;
            }
            offset = i;
            res->port = (uint16_t)port;
        }
    }
    res->hostportlen = (size_t)(uri + offset + ipv6addr - res->host);
    for (i = offset; i < len; ++i) {
        if (uri[i] == '#') {
            break;
        }
    }
    if (i - offset == 0) {
        res->path = "/";
        res->pathlen = 1;
    } else {
        res->path = &uri[offset];
        res->pathlen = i - offset;
    }
    return 0;
}

static void request_init(struct Request *req, const struct URI *uri)
{
    req->host = strcopy(uri->host, uri->hostlen);
    req->port = uri->port;
    req->path = strcopy(uri->path, uri->pathlen);
    req->hostport = strcopy(uri->hostport, uri->hostportlen);
    req->stream_id = -1;
}

static void request_free(struct Request *req)
{
    free(req->host);
    free(req->path);
    free(req->hostport);
}

/*
 * Connects to the host |host| and port |port|.  This function returns
 * the file descriptor of the client socket.
 */
static int connect_to(const char *host, uint16_t port) {
    struct addrinfo hints;
    int fd = -1;
    int rv;
    char service[NI_MAXSERV];
    struct addrinfo *res, *rp;
    snprintf(service, sizeof(service), "%u", port);
    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    rv = getaddrinfo(host, service, &hints, &res);
    if (rv != 0) {
        print_error("getaddrinfo", gai_strerror(rv));
        return rv;
    }
    for (rp = res; rp; rp = rp->ai_next) {
        fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if (fd == -1) {
            continue;
        }
        while ((rv = connect(fd, rp->ai_addr, rp->ai_addrlen)) == -1 &&
               errno == EINTR)
            ;
        if (rv == 0) {
            break;
        }
        close(fd);
        fd = -1;
    }
    freeaddrinfo(res);
    return fd;
}

/*
 * Callback function for TLS NPN. Since this program only supports
 * HTTP/2 protocol, if server does not offer HTTP/2 the nghttp2
 * library supports, we terminate program.
 */
static int select_next_proto_cb(SSL *ssl , unsigned char **out,
                                unsigned char *outlen, const unsigned char *in,
                                unsigned int inlen, void *arg) {
    int rv = SSL_TLSEXT_ERR_OK;
    /* nghttp2_select_next_protocol() selects HTTP/2 protocol the
     nghttp2 library supports. */
    rv = nghttp2_select_next_protocol(out, outlen, in, inlen);
    if (rv <= 0) {
        printf("Server did not advertise HTTP/2 protocol");
        rv = -99;
    }
    return rv;
}

/*
 * Setup SSL/TLS context.
 */
static void init_ssl_ctx(SSL_CTX *ssl_ctx) {
    /* Disable SSLv2 and enable all workarounds for buggy servers */
    SSL_CTX_set_options(ssl_ctx, SSL_OP_ALL | SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3);
    SSL_CTX_set_mode(ssl_ctx, SSL_MODE_AUTO_RETRY);
    SSL_CTX_set_mode(ssl_ctx, SSL_MODE_RELEASE_BUFFERS);
    /* Set NPN callback */
    SSL_CTX_set_next_proto_select_cb(ssl_ctx, select_next_proto_cb, NULL);
}

static int ssl_handshake(SSL *ssl, int fd) {
    int rv;
    if (SSL_set_fd(ssl, fd) == 0) {
        print_error("SSL_set_fd", ERR_error_string(ERR_get_error(), NULL));
    }
    ERR_clear_error();
    rv = SSL_connect(ssl);
    if (rv <= 0) {
        print_error("SSL_connect", ERR_error_string(ERR_get_error(), NULL));
    }
    return rv;
}

int probe(const char * url)
{
    struct URI uri;
    struct sigaction act;
    int rv;

    memset(&act, 0, sizeof(struct sigaction));
    act.sa_handler = SIG_IGN;
    sigaction(SIGPIPE, &act, 0);

    rv = parse_uri(&uri, url);
    if (rv != 0) {
        return rv;
    }

    int fd;
    SSL_CTX *ssl_ctx;
    SSL *ssl;
    struct Request req;
    request_init(&req, &uri);

    /* Establish connection and setup SSL */
    fd = connect_to(req.host, req.port);
    if (fd == -1) {
        printf("Could not open file descriptor");
        rv = -1;
        goto cleanup_req;
    }
    ssl_ctx = SSL_CTX_new(SSLv23_client_method());
    if (ssl_ctx == NULL) {
        print_error("SSL_CTX_new", ERR_error_string(ERR_get_error(), NULL));
        rv = -2;
        goto cleanup_fd;
    }
    init_ssl_ctx(ssl_ctx);
    ssl = SSL_new(ssl_ctx);
    if (ssl == NULL) {
        print_error("SSL_new", ERR_error_string(ERR_get_error(), NULL));
        rv = -3;
        goto cleanup_ssl_ctx;
    }

    /* To simplify the program, we perform SSL/TLS handshake in blocking
     I/O. */
    rv = ssl_handshake(ssl, fd);

cleanup_ssl:
    SSL_shutdown(ssl);
    SSL_free(ssl);
cleanup_ssl_ctx:
    SSL_CTX_free(ssl_ctx);
cleanup_fd:
    shutdown(fd, SHUT_WR);
    close(fd);
cleanup_req:
    request_free(&req);
    return rv;
}
