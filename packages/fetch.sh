#!/bin/sh

ARCH="amd64 i386"
LIST="../site/install.pkgs"
SITE="http://ftp.eu.openbsd.org/pub/OpenBSD/5.0/packages"

cd $(dirname $0)

for a in $ARCH; do
    test -d $a || mkdir $a
    while read pkg _; do
        ( cd $a && wget -N "${SITE}/${a}/${pkg}.tgz" )
    done < $LIST
done
