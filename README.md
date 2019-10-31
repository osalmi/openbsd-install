# Patches for OpenBSD automatic install

* Get the [source](https://www.openbsd.org/anoncvs.html)
* Create signify keys for site tarball

```
# cd /etc/signify && signify -G -p site.pub -s site.sec
```
 
* Patch and build the install image

```
# cd /usr/src
# make obj
# make -C distrib/special/libstubs depend all install
# ftp -o - https://github.com/osalmi/openbsd-install/archive/master.tar.gz |
  tar -zxvf - -s '%[^/]*/*%%'
# patch -b -p0 < patch/auto66.patch
# cd /usr/src/distrib/amd64/ramdisk_cd
# make          # obj/bsd.rd obj/miniroot66.fs obj/cd66.iso
```

* Create and sign the site tarball

```
# cd /usr/src/site
# tar zcvf ../site66.tgz *
# cd ..
# signify -S -e -s /etc/signify/site.sec -m site66.tgz -x site66.tgz.sig
```
