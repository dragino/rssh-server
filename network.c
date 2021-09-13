/*
 *  ____  ____      _    ____ ___ _   _  ___  
 *  |  _ \|  _ \    / \  / ___|_ _| \ | |/ _ \ 
 *  | | | | |_) |  / _ \| |  _ | ||  \| | | | |
 *  | |_| |  _ <  / ___ \ |_| || || |\  | |_| |
 *  |____/|_| \_\/_/   \_\____|___|_| \_|\___/ 
 *
 * Dragino Forward -- An opensource lora gateway forward 
 *
 * See http://www.dragino.com for more information about
 * the lora gateway project. Please do not directly contact
 * any of the maintainers of this project for assistance;
 *
 * This program is free software, distributed under the terms of
 * the GNU General Public License Version 2. See the LICENSE file
 * at the top of the source tree.
 *
 * Maintainer: skerlan
 *
 */

#include <netdb.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/select.h>

#include "logger.h"
#include "network.h"

int get_local_port() {
    int port = 0;
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) return port;
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = 0;        // 若port指定为0,则调用bind时，系统会为其指定一个可用的端口号
    int ret = bind(sock, (struct sockaddr *) &addr, sizeof addr);    
    do {
        if (0 != ret) {
            lgw_log(LOG_DEBUG, "upn bind, %d, %s\n", errno, strerror(errno));
            break;
        }
        struct sockaddr_in sockaddr;
        int len = sizeof(sockaddr);
        ret = getsockname(sock, (struct sockaddr *) &sockaddr, (socklen_t *) &len); // this function now not be hooked

        if (0 != ret) {
            lgw_log(LOG_DEBUG, "upn, getsockname:%d, %s\n", errno, strerror(errno));
            break;
        }
        port = ntohs(sockaddr.sin_port); // 获取端口号
    } while (false);
    lgw_log(LOG_DEBUG, "::get::port::%d\n", port);
    close(sock);

    return port;
}

int get_connect_state(int port, const char *ip, int tv_sec, int tv_usec) {
    int fd = -1;
    int ret = 0;
    do {
        fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) {
            lgw_log(LOG_DEBUG, "Test::connect:socket: %d, %s", errno, strerror(errno));
            break;
        }
        struct sockaddr_in addr;
        bzero(&addr, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port);
        addr.sin_addr.s_addr = inet_addr(ip);

        int flags = fcntl(fd, F_GETFL, 0);
        if (flags < 0) {
            lgw_log(LOG_DEBUG, "Test::connect:get flags: %d, %s", errno, strerror(errno));
            break;
        }
        flags |= O_NONBLOCK;
        if (fcntl(fd, F_SETFL, (void *) flags) < 0) {
            lgw_log(LOG_DEBUG, "Test::connect:set flags: %d, %s", errno, strerror(errno));
            break;
        }
        if (0 == connect(fd, (struct sockaddr *) &addr, sizeof(addr))) {
            break;
        }
        lgw_log(LOG_DEBUG, "Test::connect:failed: %d, %s", errno, strerror(errno));
        if (EINPROGRESS != errno) {
            lgw_log(LOG_DEBUG, "Test::connect:failed: %d, %s", errno, strerror(errno));
            break;
        }
        fd_set fdr, fdw;
        FD_ZERO(&fdr);
        FD_ZERO(&fdw);
        FD_SET(fd, &fdr);
        FD_SET(fd, &fdw);

        struct timeval timeout;
        timeout.tv_sec = tv_sec;// seconds
        timeout.tv_usec = tv_usec;
        int rc = select(fd + 1, &fdr, &fdw, NULL, &timeout);
        if (0 < rc && (FD_ISSET(fd, &fdw) || FD_ISSET(fd, &fdr))) {
            break;
        }
        if (rc < 0) {
            lgw_log(LOG_DEBUG, "Test::connect:select: %d, %d, %s", rc, errno, strerror(errno));
            break;
        }
        if (0 == rc) {
            lgw_log(LOG_DEBUG, "Test::connect:time out: %d, %s", errno, strerror(errno));
            break;
        }
    } while (false);
    if (0 <= fd) {
        close(fd);
    }
    return ret;
}

int udp_server(char* service)
{

    int i;
    /* server socket creation */
    int sock; /* socket file descriptor */
    struct addrinfo hints;
    struct addrinfo *result; /* store result of getaddrinfo */
    struct addrinfo *q; /* pointer to move into *result data */
    char host_name[64];
    char port_name[64];

    /* prepare hints to open network sockets */
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC; /* should handle IP v4 or v6 automatically */
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_flags = AI_PASSIVE; /* will assign local IP automatically */

    /* look for address */
    i = getaddrinfo(NULL, service, &hints, &result);
    if (i != 0) {
        MSG("ERROR: getaddrinfo returned %s\n", gai_strerror(i));
        return -1;
    }

    /* try to open socket and bind it */
    for (q=result; q!=NULL; q=q->ai_next) {
        sock = socket(q->ai_family, q->ai_socktype,q->ai_protocol);
        if (sock == -1) {
            continue; /* socket failed, try next field */
        } else {
            i = bind(sock, q->ai_addr, q->ai_addrlen);
            if (i == -1) {
                shutdown(sock, SHUT_RDWR);
                continue; /* bind failed, try next field */
            } else {
                break; /* success, get out of loop */
            }
        }
    }
    if (q == NULL) {
        MSG("ERROR: failed to open socket or to bind to it\n");
        i = 1;
        for (q=result; q!=NULL; q=q->ai_next) {
            getnameinfo(q->ai_addr, q->ai_addrlen, host_name, sizeof host_name, port_name, sizeof port_name, NI_NUMERICHOST);
            MSG("INFO: result %i host:%s service:%s\n", i, host_name, port_name);
            ++i;
        }
        return -1;
    }
    MSG("INFO: util_rssh listening on port %s\n", service);
    freeaddrinfo(result);

    return sock;
}

