#!/usr/bin/expect -f

set id [lindex $argv 0]
log_user 0
spawn ssh -i "RSSHServer.pem"  ec2-user@ec2-54-74-106-41.eu-west-1.compute.amazonaws.com "/home/ec2-user/rssh-server/./gateway.sh -c ${id}" 
log_user 1
interact
