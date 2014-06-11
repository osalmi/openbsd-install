VERSION != uname -r | tr -d .
PATCH = ${.CURDIR}/auto${VERSION}.patch

patch:
	test -s ${PATCH} && cp -pf ${PATCH} ${PATCH}.orig
	cd /usr/src && find distrib sys -type f -name *.orig | sort |\
		while read f; do diff -u $$f $${f%.orig} || true; done\
		> ${PATCH}
