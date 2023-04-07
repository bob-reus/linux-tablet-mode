#!/bin/bash
cp monitor-rotate.sh /usr/local/bin
chmod +x /usr/local/bin/monitor-rotate.sh

cp monitor-rotate.service /etc/systemd/system/monitor-rotate.service
chmod 640 /etc/systemd/system/monitor-rotate.service

systemctl daemon-reload
systemctl enable monitor-rotate
systemctl start monitor-rotate