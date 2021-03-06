# Copyright 1999-2018 Gentoo Foundation
# Copyright 2014 Julian Ospald <hasufell@posteo.de>
# Distributed under the terms of the GNU General Public License v2

EAPI=5
inherit eutils toolchain-funcs flag-o-matic gamers

MY_PV=${PV//.}
DESCRIPTION="The ultimate old-school single player dungeon exploration game"
HOMEPAGE="http://www.nethack.org/"
SRC_URI="mirror://sourceforge/nethack/${PN}-${MY_PV}-src.tgz"

LICENSE="nethack"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="X"

RDEPEND=">=sys-libs/ncurses-5.2-r5
	X? (
		x11-libs/libXaw
		x11-libs/libXpm
		x11-libs/libXt
	)"
DEPEND="${RDEPEND}
	virtual/pkgconfig
	X? (
		x11-proto/xproto
		x11-apps/bdftopcf
		x11-apps/mkfontdir
	)"

HACKDIR=/usr/share/${PN}

src_prepare() {
	# This copies the /sys/unix Makefile.*s to their correct places for
	# seding and compiling.
	cd "sys/unix"
	source setup.sh || die

	cd ../..
	epatch \
		"${FILESDIR}"/${PV}-gentoo-paths.patch \
		"${FILESDIR}"/${PV}-default-options.patch \
		"${FILESDIR}"/${PV}-bison.patch \
		"${FILESDIR}"/${PV}-macos.patch \
		"${FILESDIR}"/${P}-gibc210.patch \
		"${FILESDIR}"/${P}-recover.patch

	mv doc/recover.6 doc/nethack-recover.6

	sed -i \
		-e "s:GENTOO_STATEDIR:/var/lib/games/nethack:" include/unixconf.h \
		|| die "setting statedir"
	sed -i \
		-e "s:GENTOO_HACKDIR:${HACKDIR}:" include/config.h \
		|| die "setting hackdir"
	# set the default pager from the environment bug #52122
	if [[ -n "${PAGER}" ]] ; then
		sed -i \
			-e "115c\#define DEF_PAGER \"${PAGER}\"" \
			include/unixconf.h \
			|| die "setting statedir"
		# bug #57410
		sed -i \
			-e "s/^DATNODLB =/DATNODLB = \$(DATHELP)/" Makefile \
			|| die "sed Makefile failed"
	fi

	# sys-libs/ncurses[tinfo]
	sed -i \
		-e '/^WINTTYLIB/s| = .*| = '"$(
				$(tc-getPKG_CONFIG) --libs ncurses
			)"'|g' \
		src/Makefile || die

	if use X ; then
		epatch "${FILESDIR}/${PV}-X-support.patch"
	fi
}

src_compile() {
	local lflags="${LDFLAGS}"

	tc-export CC CXX LD AR RANLIB

	cd "${S}"/src
	append-flags -I../include

	emake \
		CC="$(tc-getCC)" \
		CFLAGS="${CFLAGS}" \
		LFLAGS="${lflags}" \
		../util/makedefs \
		|| die "initial makedefs build failed"
	emake \
		CC="$(tc-getCC)" \
		CFLAGS="${CFLAGS}" \
		LFLAGS="${lflags}" \
		|| die "main build failed"
	cd "${S}"/util
	emake \
		CC="$(tc-getCC)" \
		CFLAGS="${CFLAGS}" \
		LFLAGS="${lflags}" \
		recover || die "util build failed"
}

src_install() {
	emake \
		CC="$(tc-getCC)" \
		CFLAGS="${CFLAGS}" \
		LFLAGS="-L/usr/X11R6/lib" \
		GAMEPERM=0755 \
		GAMEUID=root GAMEGRP=root \
		PREFIX="${D}/usr" \
		GAMEDIR="${D}${HACKDIR}" \
		SHELLDIR="${D}/usr/bin" \
		VARDIR="${D}"/var/lib/games/nethack \
		install \
		|| die "emake install failed"

	rm -rf "${D}/usr/share/games/nethack/save"

	newbin util/recover recover-nethack

	# The final nethack is a sh script.  This fixes the hard-coded
	# HACKDIR directory so it doesn't point to ${D}/usr/share/nethackdir
	sed -i \
		-e "s:^\(HACKDIR=\).*:\1${HACKDIR}:" \
		"${D}/usr/bin/nethack" \
		|| die "sed /usr/bin/nethack failed"

	doman doc/*.6
	dodoc doc/*.txt

	# Can be copied to ~/.nethackrc to set options
	# Add this to /etc/.skel as well, thats the place for default configs
	insinto "${HACKDIR}"
	doins "${FILESDIR}/dot.nethackrc"

	local windowtypes="tty"
	use X && windowtypes="${windowtypes} x11"
	set -- ${windowtypes}
	sed -i \
		-e "s:GENTOO_WINDOWTYPES:${windowtypes}:" \
		-e "s:GENTOO_DEFWINDOWTYPE:$1:" \
		"${D}${HACKDIR}/dot.nethackrc" \
		|| die "sed ${HACKDIR}/dot.nethackrc failed"
	insinto /etc/skel
	newins "${D}/${HACKDIR}/dot.nethackrc" .nethackrc

	if use X ; then
		# install nethack fonts
		cd "${S}/win/X11"
		bdftopcf -o nh10.pcf nh10.bdf || die "Converting fonts failed"
		bdftopcf -o ibm.pcf ibm.bdf || die "Converting fonts failed"
		insinto "${HACKDIR}/fonts"
		doins *.pcf
		cd "${D}/${HACKDIR}/fonts"
		mkfontdir || die "The action mkfontdir ${HACKDIR}/fonts failed"

		# copy nethack x application defaults
		cd "${S}/win/X11"
		insinto /etc/X11/app-defaults
		newins NetHack.ad NetHack || die "Failed to install NetHack X app defaults"
		sed -i \
			-e 's:^!\(NetHack.tile_file.*\):\1:' \
			"${D}/etc/X11/app-defaults/NetHack" \
			|| die "sed /etc/X11/app-defaults/NetHack failed"
	fi

	local statedir="/var/lib/games/${PN}"
	keepdir "${statedir}/save"
	gamers_prep_vardata -R
	gamers_preserve_vardata "${statedir}"/*
	make_desktop_entry nethack "Nethack"
	chmod o-r "${D}${statedir}" || die
}

pkg_postinst() {
	elog "You may want to look at /etc/skel/.nethackrc for interesting options"
	gamers_pkg_postinst
}
