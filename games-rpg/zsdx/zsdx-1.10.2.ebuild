# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=5

inherit cmake-utils gnome2-utils

DESCRIPTION="A free 2D Zelda fangame"
HOMEPAGE="http://www.solarus-games.org/"
SRC_URI="http://www.zelda-solarus.com/downloads/${PN}/${P}.tar.gz"

LICENSE="all-rights-reserved CC-BY-SA-3.0 GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""
RESTRICT="mirror"

RDEPEND=">=games-engines/solarus-1.4.0
	<games-engines/solarus-1.5.0"
DEPEND="app-arch/zip"

DOCS=( ChangeLog readme.txt )

src_prepare() {
	cmake-utils_src_prepare
}

src_configure() {
	local mycmakeargs=(
		-DSOLARUS_INSTALL_DATAROOTDIR=/usr/share
		-DSOLARUS_INSTALL_BINDIR=/usr/bin
	)
	cmake-utils_src_configure
}

src_compile() {
	cmake-utils_src_compile
}

src_install() {
	cmake-utils_src_install
	newicon -s 48 build/icons/${PN}_icon_48.png ${PN}.png
	newicon -s 256 build/icons/${PN}_icon_256.png ${PN}.png

	# install proper wrapper script
	rm -f "${ED%/}"/usr/share/${PN}
	make_wrapper ${PN} "solarus_run \"/usr/share/solarus/${PN}\""

	make_desktop_entry "${PN}" "Zelda: Mystery of Solarus DX"
}
