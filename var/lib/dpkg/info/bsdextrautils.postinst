#!/bin/sh
set -e

if [ "$1" = "configure" ] || [ "$1" = "abort-upgrade" ] ; then
    update-alternatives \
        --install /usr/bin/write write /usr/bin/write.ul 100 \
        --slave /usr/share/man/man1/write.1.gz write.1.gz /usr/share/man/man1/write.ul.1.gz
fi


