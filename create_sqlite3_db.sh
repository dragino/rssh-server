#!/bin/sh

sqlite3 /var/rsshdb.sqlite3  "CREATE TABLE IF NOT EXISTS rsshtb(key VARCHAR(256), value VARCHAR(512), PRIMARY KEY(key));"
