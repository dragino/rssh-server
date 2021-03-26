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
 * \brief FWD main include file . File version handling , generic functions.
 */

#ifndef _LGW_LOGGER_H
#define _LGW_LOGGER_H

#include <stdint.h>
#include <stdio.h>

extern uint8_t LOG_INFO;
extern uint8_t LOG_WARNING;
extern uint8_t LOG_ERROR;
extern uint8_t LOG_DEBUG;

#define MSG(args...) printf(args) /* message that is destined to the user */

#define LOGD(fmt, ...)   fprintf(stdout, fmt, ##__VA_ARGS__) 
#define LOGE(fmt, ...)   fprintf(stderr, fmt, ##__VA_ARGS__) 

#define lgw_log(FLAG, fmt, ...)                               \
            do  {                                             \
                if (FLAG)                                     \
                    fprintf(stdout, fmt, ##__VA_ARGS__);      \
                } while (0)

#endif /* _LGW_LOGGER_H */
