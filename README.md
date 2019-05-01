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
# ftp -o - https://github.com/osalmi/openbsd-install/archive/master.tar.gz | \
  tar -zxvf - -s '%[^/]*/*%%'
# patch -b -p0 < patch/auto65.patch
# cd /usr/src/distrib/amd64
# make -C ramdisk_cd    # ramdisk_cd/obj/bsd.rd ramdisk_cd/obj/miniroot65.fs
# make -C cdfs          # cdfs/obj/cd65.iso
```

* Create and sign the site tarball

```
# cd /usr/src/site
# tar zcvf ../site65.tgz *
# cd ..
# signify -S -e -s /etc/signify/site.sec -m site65.tgz -x site65.tgz.sig
```
