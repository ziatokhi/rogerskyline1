#!/bin/bash

cat /etc/crontab > /root/script/new
DIFF=$(diff /root/script/new /root/script/tmp)
if [ "$DIFF" != "" ]; then
	cp /root/script/mail_type.txt /root/script/mail.txt
	diff /root/script/new /root/script/tmp >> /root/script/mail.txt
	sudo sendmail -vt < /root/script/mail.txt
	rm -f /root/script/tmp
	rm -f /root/scrip/mail.txt
	cp /root/script/new /root/script/tmp
fi
