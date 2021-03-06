#!/bin/sh -x
source /tmp/envscript

fix_locale() {
  for i in /etc/locale.nopurge /etc/locale.gen; do
  	echo C.UTF-8 UTF-8 > "${i}"
  	echo en_US ISO-8859-1 >> "${i}"
  	echo en_US.UTF-8 UTF-8 >> "${i}"
  done
	eselect locale set C.utf8 || /bin/bash
  env-update
  . /etc/profile
	locale-gen || /bin/bash
}

fix_locale
printf "fuck\n"
/bin/bash

#revdep-rebuild --library 'libstdc++.so.6' -- --buildpkg=y --usepkg=n --exclude gcc

emerge -1kb --newuse --update sys-apps/portage || /bin/bash

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash

#ease transition to the new use flags
USE="-qt5" emerge -1 -kb cmake || /bin/bash
portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

#merge in the profile set since we have no @system set
emerge -1kb --newuse --update @profile || /bin/bash
#finish transition to the new use flags
emerge --deep --update --newuse -kb @world || /bin/bash
#do what stage1 update seed is going to do
emerge --quiet --update --newuse --changed-deps --oneshot --deep --changed-use --rebuild-if-new-rev sys-devel/gcc dev-libs/mpfr dev-libs/mpc dev-libs/gmp sys-libs/glibc app-arch/lbzip2 sys-devel/libtool dev-lang/perl net-misc/openssh dev-libs/openssl sys-libs/readline sys-libs/ncurses || /bin/bash
portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

#fix interpreted stuff
perl-cleaner --all -- --buildpkg=y || /bin/bash
portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

#first we set the python interpreters to match PYTHON_TARGETS
PYTHON2=$(emerge --info | grep '^PYTHON_TARGETS' | cut -d\" -f2 | cut -d" " -f 1 |sed 's#_#.#')
PYTHON3=$(emerge --info | grep '^PYTHON_TARGETS' | cut -d\" -f2 | cut -d" " -f 2 |sed 's#_#.#')
eselect python set --python2 ${PYTHON2} || /bin/bash
eselect python set --python3 ${PYTHON3} || /bin/bash
${PYTHON2} -c "from _multiprocessing import SemLock" || emerge -1 --buildpkg=y python:${PYTHON2#python}
${PYTHON3} -c "from _multiprocessing import SemLock" || emerge -1 --buildpkg=y python:${PYTHON3#python}
#python 3 by default now
eselect python set $(emerge --info | grep '^PYTHON_TARGETS' | cut -d\" -f2 | cut -d" " -f 2 |sed 's#_#.#') || /bin/bash
if [ -x /usr/sbin/python-updater ];then
	python-updater -- --buildpkg=y || /bin/bash
fi

portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

emerge -1 -kb app-portage/gentoolkit || /bin/bash

portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

revdep-rebuild -i -- --usepkg=n --buildpkg=y || /bin/bash

[ -x /usr/local/portage/scripts/bug-461824.sh ] && /usr/local/portage/scripts/bug-461824.sh
[ -x /var/gentoo/repos/local/scripts/bug-461824.sh ] && /var/gentoo/repos/local/scripts/bug-461824.sh

#some things fail in livecd-stage1 but work here, nfc why
emerge -1 -kb sys-kernel/pentoo-sources || /bin/bash
#emerge -1 -kb app-crypt/johntheripper || /bin/bash

#fix java circular deps in next stage
emerge --update --oneshot -kb dev-java/icedtea-bin || /bin/bash
#oh, and f**king tomcat can't build against openjdk:11
eselect java-vm set system icedtea-bin-8 || /bin/bash
if [ "$(uname -m)" = "x86_64" ]; then
  emerge --update --oneshot -kb dev-java/tomcat-servlet-api:2.4 || /bin/bash
  emerge --update --oneshot -kb openjdk-bin:11 || /bin/bash
  eselect java-vm set system openjdk-bin-11 || /bin/bash
  emerge --update --oneshot -kb openjdk:11 || /bin/bash
  eselect java-vm set system openjdk-11 || /bin/bash
  emerge -C openjdk-bin:11 || /bin/bash
fi
if [ "$(uname -m)" = "x86" ]; then
	emerge --update --oneshot -kb dev-lang/rust-bin || /bin/bash
fi
portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

#add 64 bit toolchain to 32 bit iso to build dual kernel iso someday
#[ "$(uname -m)" = "x86" ] && crossdev -s1 -t x86_64

fixpackages
eclean-pkg -t 3m
emerge --depclean --exclude dev-java/openjdk-bin  --exclude sys-kernel/pentoo-sources \
	--exclude dev-lang/rust-bin --exclude app-portage/gentoolkit --exclude dev-java/icedtea-bin \
  --exclude dev-java/tomcat-servlet-api --exclude dev-java/icedtea || /bin/bash

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash
