#!/var/jb/bin/sh
export PATH=/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin
tail -n 25 /var/mobile/Downloads/onerlay_daemon.log; ps -ef | grep SpringBoard | grep -v grep