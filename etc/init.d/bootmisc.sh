#!/bin/sh
### BEGIN INIT INFO
# Provides:          bootmisc
# Required-Start:    $remote_fs
# Required-Stop:
# Should-Start:      udev
# Default-Start:     S
# Default-Stop:
# Short-Description: Miscellaneous things to be done during bootup.
# Description:       Some cleanup.  Note, it need to run after mountnfs-bootclean.sh.
### END INIT INFO

PATH=/usr/sbin:/usr/bin:/sbin:/bin
[ "$DELAYLOGIN" ] || DELAYLOGIN=yes
. /lib/lsb/init-functions
. /lib/init/vars.sh

do_start () {
	#
	# If login delaying is enabled then create the flag file
	# which prevents logins before startup is complete
	#
	case "$DELAYLOGIN" in
	  Y*|y*)
		echo "System bootup in progress - please wait" > /run/nologin
		;;
	esac

	# Remove bootclean's flag files.
	# Don't run bootclean again after this!
	rm -f /tmp/.clean /run/.clean /run/lock/.clean
	rm -f /tmp/.tmpfs /run/.tmpfs /run/lock/.tmpfs

	readonly utmp='/var/run/utmp'
	if > "${utmp}" ; then
		chgrp utmp "${utmp}" || log_warning_msg "failed to chgrp ${utmp}"
		chmod 664  "${utmp}" || log_warning_msg "failed to chmod ${utmp}"
		return 0
	else
		log_failure_msg "failed to truncate ${utmp}"
		return 1
	fi
}

case "$1" in
  start|"")
	do_start
	;;
  restart|reload|force-reload)
	echo "Error: argument '$1' not supported" >&2
	exit 3
	;;
  stop|status)
	# No-op
	;;
  *)
	echo "Usage: bootmisc.sh [start|stop]" >&2
	exit 3
	;;
esac

:
