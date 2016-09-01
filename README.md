# Patches for OpenBSD automatic install

* Get the [source](https://www.openbsd.org/anoncvs.html)
* Create signify keys for site tarball

```
# cd /etc/signify && signify -G -p site.pub -s site.sec
```
 
* Patch and build the install image

```
# cd /usr/src
# ftp -o - https://bitbucket.org/osalmi/openbsd-ai/get/master.tar.gz | \
  tar -zxvf - -s '%[^/]*/*%%'
# patch -b -p0 < patch/auto60.patch
# make -C distrib/special/libstubs obj depend all install
# cd /usr/src/distrib/amd64
# make -C ramdisk_cd clean bsd.rd
# make -C cdfs clean cd60.iso
```

* Create and sign the site tarball

```
# cd /usr/src/site
# tar zcvf ../site60.tgz *
# cd ..
# signify -S -e -s /etc/signify/site.sec -m site60.tgz -x site60.tgz.sig
```
