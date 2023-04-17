#!/bin/bash
# Script to update contents of /etc/init.d/ with scripts from
# /usr/share/orphan-sysvinit-scripts.
# This should be called automatically by dpkg
# If $1 is --purge, removes everything, otherwise will add
# scripts corresponding to installed service files.

set -e

if [ -z "$1" ]; then
    action=add
elif [ "$1" = "--purge" ]; then
    action=purge
else
    echo "update_init_d.sh: Error: only allowed argument is --purge"
    exit 1
fi

while read -r systemd sysv rcd rest ; do
    #Comment lines
    if [[ $systemd =~ ^# ]]; then
	continue
    fi
    if [ -n "$rest" ]; then
	echo "Unable to parse line: $systemd $sysv $rcd $rest"
	exit 1
    fi
    if [ -e "/lib/systemd/system/$systemd" ] && [ "$action" = "add" ]; then
	ucf "/usr/share/orphan-sysvinit-scripts/$sysv" "/etc/init.d/$sysv"
	ucfr orphan-sysvinit-scripts "/etc/init.d/$sysv"
	update-rc.d "$sysv" "${rcd:-defaults}" >/dev/null
    elif [ -e "/etc/init.d/$sysv" ] && [ "$action" = "purge" ]; then
	#Only remove scripts if we are reasonably sure we have previously
	#registered them with ucf (to minimise user surprise)
	if which ucfq >/dev/null; then
	    if ucfq "/etc/init.d/$sysv" | grep -q orphan-sysvinit-scripts ; then
		for ext in '~' '%' .bak .ucf-new .ucf-old .ucf-dist; do
		    rm -f "/etc/init.d/${sysv}.$ext"
		done
		rm -f "/etc/init.d/$sysv"
		ucf --purge "/etc/init.d/$sysv"
		ucfr --purge orphan-sysvinit-scripts "/etc/init.d/$sysv"
		update-rc.d "$sysv" remove >/dev/null
	    fi
	fi
    fi
done < /usr/lib/orphan-sysvinit-scripts/mapping
