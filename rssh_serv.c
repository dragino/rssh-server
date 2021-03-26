/*
 *  ____  ____      _    ____ ___ _   _  ___  
 *  |  _ \|  _ \    / \  / ___|_ _| \ | |/ _ \ 
 *  | | | | |_) |  / _ \| |  _ | ||  \| | | | |
 *  | |_| |  _ <  / ___ \ |_| || || |\  | |_| |
 *  |____/|_| \_\/_/   \_\____|___|_| \_|\___/ 
 *
 * Dragino RSSH SERVICE 
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

/*!
 * \file
 * \brief 
 */

#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <netdb.h>
#include <time.h>
#include <signal.h> 

#include <arpa/inet.h>
#include <sys/socket.h>


#include "network.h"
#include "db.h"
#include "util_rssh.h"
#include "logger.h"

#define PROTOCOL_VERSION    1

volatile bool exit_sig = false; 

/* -------------------------------------------------------------------------- */
/* --- PUBLIC DECLARATION ---------------------------------------- */
uint8_t LOG_INFO = 1;
uint8_t LOG_DEBUG = 1;
uint8_t LOG_WARNING = 1;
uint8_t LOG_ERROR = 1;

static void sig_handler(int sigio) {
    if (sigio == SIGQUIT) {
        exit_sig = true;
    } else if ((sigio == SIGINT) || (sigio == SIGTERM)) {
        exit_sig = true;
    }
    return;
}

int main(int argc, char* argv[]) {
    int i; /* loop variable and temporary variable for return value */

    struct sigaction sigact;    /* SIGQUIT&SIGINT&SIGTERM signal handling */

    int sock = -1; /* socket file descriptor */

    struct addrinfo hints;
    struct addrinfo *result; /* store result of getaddrinfo */
    struct addrinfo *q; /* pointer to move into *result data */
    char host_name[64];
    char port_name[64];

    char service[16] = "3721";  // default udp server port;

    char db_value[128] = {'\0'};
    char db_family[128] = {'\0'};

    struct sockaddr_storage dist_addr;
    socklen_t addr_len = sizeof dist_addr;
    uint8_t databuf[4096] = {'\0'};
    int byte_nb, buf_len;
    int lc_port = -1;

    int16_t token;
    uint32_t raw_mac_h; /* Most Significant Nibble, network order */
    uint32_t raw_mac_l; /* Least Significant Nibble, network order */
    uint64_t gw_mac; /* MAC address of the client (gateway) */
    char str_mac[24] = {'\0'};

    time_t current_time;
    char stat_timestamp[24];

    /* configure signal handling */
    sigemptyset(&sigact.sa_mask);
    sigact.sa_flags = 0;
    sigact.sa_handler = sig_handler;
    sigaction(SIGQUIT, &sigact, NULL);  /* Ctrl-\ */
    sigaction(SIGINT, &sigact, NULL);   /* Ctrl-C */
    sigaction(SIGTERM, &sigact, NULL);  /* default "kill" command */
    sigaction(SIGQUIT, &sigact, NULL);  /* Ctrl-\ */

    /* Parse command line options */
    while( (i = getopt( argc, argv, "p:d:" )) != -1 )
    {
        switch( i ) {

        case 'p':
            if (NULL != optarg)
                strncpy(service, optarg, sizeof(service));
            break;

        default:
            break;
        }
    }

    if (lgw_db_init()) {
        lgw_log(LOG_INFO, "ERROR~ Can't initiate sqlite3 database, EXIT!\n");
        exit(EXIT_FAILURE);
    }

    sock = udp_server(service);
    if (sock == -1) {
        lgw_log(LOG_INFO, "ERROR~ Can't create rssh service, EXIT!\n");
        exit(EXIT_FAILURE);
    }

    while (!exit_sig) {
        /* wait to receive a packet */
        byte_nb = recvfrom(sock, databuf, sizeof databuf, 0, (struct sockaddr *)&dist_addr, &addr_len);
        if (byte_nb == -1) {
            lgw_log(LOG_ERROR, "ERROR: recvfrom returned %s \n", strerror(errno));
            continue;
        }

        if (byte_nb < 12) { /* not enough bytes for packet from gateway */
            lgw_log(LOG_INFO, "(too short for RSSH <-> MAC protocol)(nb=%d)\n", byte_nb);
            continue;
        }

        /* display info about the sender */
        i = getnameinfo((struct sockaddr *)&dist_addr, addr_len, host_name, sizeof host_name, port_name, sizeof port_name, NI_NUMERICHOST);
        if (i == -1) {
            lgw_log(LOG_ERROR, "ERROR: getnameinfo returned %s \n", gai_strerror(i));
            continue;
        }

        if (databuf[0] != PROTOCOL_VERSION) { /* check protocol version number */
            lgw_log(LOG_WARNING, "invalid version %u\n", databuf[0]);
            continue;
        }

        token = *((int16_t*)(databuf + 1));
        raw_mac_h = *((uint32_t *)(databuf + 4));
        raw_mac_l = *((uint32_t *)(databuf + 8));
        gw_mac = ((uint64_t)ntohl(raw_mac_h) << 32) + (uint64_t)ntohl(raw_mac_l);
        unsigned long long ull = gw_mac;
        sprintf(str_mac, "%016llX", ull);    
        lgw_log(LOG_DEBUG, "receive gateway mac %lu, str: %s\n", gw_mac, str_mac);
        sprintf(db_family, "/token/%s", str_mac);    //检查数据库是否有和MAC相对应的重复的token
        if (lgw_db_key_exist(db_family)) {
            lgw_db_get("/token", str_mac, db_value, sizeof(db_value));
            if (token == atoi(db_value)) {
                lgw_log(LOG_INFO, "Duplicate request: %d\n", token);
                continue;
            }
            lgw_db_deltree("/token", str_mac);  
        } 

        sprintf(db_value, "%d", token);  
        lgw_db_put("/token", str_mac, db_value); // 将每个请求的token记录进入数据库

        switch (databuf[3]) {
            case PULL_PORT:
                sprintf(db_family, "/port/%s", str_mac);    
                if (lgw_db_key_exist(db_family))
                    lgw_db_deltree("/port", str_mac); //删除当前已经记录的port
                lc_port = get_local_port();
                lgw_log(LOG_DEBUG, "[%s] port request: port = %d\n", str_mac, lc_port);
                sprintf(db_value, "%d", lc_port);    //将新的port写入数据库
                lgw_db_put("/port", str_mac, db_value); 
                databuf[3] = ACK_PORT;
                *(uint16_t *)(databuf + 4) = lc_port;
                //databuf[4] = (htons(lc_port) >> 8) & 0xFF;  //返回 port 给客户端
                //databuf[5] = htons(lc_port) & 0xFF;
                buf_len = 6;
                break;
            case PUSH_STATUS:
                databuf[3] = ACK_STATUS;
                sprintf(db_family, "/status/%s", str_mac);    
                if (lgw_db_key_exist(db_family))
                    lgw_db_deltree("/status", str_mac); //删除当前已经记录的status
                current_time = time(NULL);     
                sprintf(stat_timestamp, "%ju", (uintmax_t)current_time);
                lgw_db_put("/status", str_mac, stat_timestamp);  //更新status
                buf_len = 4;
            default:
                buf_len = 0;
                break;
        }

        if (buf_len == 0) continue;

        byte_nb = sendto(sock, (void *)databuf, buf_len, 0, (struct sockaddr *)&dist_addr, addr_len);
        if (byte_nb == -1) {
            lgw_log(LOG_INFO, "[%s] send error:%s\n", str_mac, strerror(errno));
        } else {
            lgw_log(LOG_DEBUG, "[%s] %i bytes sent\n", str_mac, byte_nb);
        }
    }

    db_atexit();
}
