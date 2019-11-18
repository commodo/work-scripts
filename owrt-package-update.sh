#!/bin/bash

echo_red()   { printf "\033[1;31m$*\033[m\n"; }
echo_green() { printf "\033[1;32m$*\033[m\n"; }
echo_blue()  { printf "\033[1;34m$*\033[m\n"; }

# FIXME: hard-coded for now
OWRT_BASE_REPO="openwrt"
PACKAGES_REPO="packages"
OWRT_REMOTE="owrt"

OWN_REMOTE="commodo"

[ -n "$1" ] || {
	echo_red "No package name provided"
	exit 1
}

[ -n "$2" ] || {
	echo_red "No package version provided; version detection not implemented"
	exit 1
}

download_package() {
	local url="$1"
	local dst="$2"

	if [ -n "$dst" ] ; then
		dst="-O $dst"
	fi

	wget $url $dst
}

download_python_package() {
	local pkg="$1"
	local ver="$2"
	local dst="$3"

	local letter=${pkg:0:1}

	local source="${pkg}/${pkg}-${ver}.tar.gz"
	local url="https://files.pythonhosted.org/packages/source/${letter}/${source}"

	echo_green "Downloading from: '$url'"
	download_package "$url" "$dst"
}

download_python_get_hash() {
	local pkg="$1"
	local ver="$2"
	local varname="$3"
	local tmp=$(mktemp)
	local pkg_hash_local

	download_python_package "$pkg" "$ver" "$tmp" || {
		rm -f "$tmp"
		return 1
	}
	pkg_hash_local=$(sha256sum $tmp | cut -d' ' -f1)

	eval "$varname=${pkg_hash_local}"

	rm -f $tmp
}

check_only_one_pkg() {
	local pkg="$1"
	local count

	count=$(git grep $pkg | grep PKG_NAME | cut -d: -f1 | wc -l)

	if [ "$count" == "0" ] ; then
		echo_red "Did not find any entry for package '$pkg'"
		return 1
	fi

	if [ "$count" -gt 1 ] ; then
		echo_red "More than 1 entry found for '$pkg'"
		return 1
	fi

	return 0
}

package_get_makefile() {
	local pkg="$1"
	git grep $pkg | grep PKG_NAME | cut -d: -f1
}

package_is_python_package() {
	local makefile="$1"
	grep -q python3-package.mk $makefile || \
		grep -q python-package.mk $makefile
}

package_get_pkg_name() {
	local makefile="$1"
	grep "PKG_NAME:=" $makefile | cut -d= -f2
}

package_python_uses_pypi_mk() {
	local makefile="$1"
	grep -q "PYPI_NAME:=" $makefile
}

package_python_get_pypi_name() {
	local makefile="$1"
	grep PYPI_NAME $makefile | cut -d= -f2
}

owrt_repo_update() {
	git fetch "$OWRT_REMOTE" || {
		echo_red "Could not fetch from remote '$OWRT_REMOTE'"
		exit 1
	}

	git checkout "$OWRT_REMOTE/master" || {
		echo_red "Could not checkout '$OWRT_REMOTE/master'"
		exit 1
	}
}

do_update_and_commit() {
	local makefile="$1"
	local pkg="$2"
	local ver="$3"
	local pkg_hash="$4"

	local new_branch

	sed "s/PKG_VERSION.*/PKG_VERSION:=${ver}/g" -i "$makefile"
	sed "s/PKG_HASH.*/PKG_HASH:=${pkg_hash}/g" -i "$makefile"
	sed "s/PKG_RELEASE.*/PKG_RELEASE:=1/g" -i "$makefile"

	owrt_repo_update

	new_branch="$pkg-update"
	git checkout -b "$new_branch" || {
		git branch -D "$new_branch"
		echo_red "Error when creating new branch '$new_branch'"
		exit 1
	}

	git add $makefile || {
		git branch -D "$new_branch"
		echo_red "Error when staging file '$makefile'"
		exit 1
	}
	git commit -s -F - <<-EOF
		${pkg}: bump to version ${ver}
	EOF
}

do_cherry_pick_to_staging() {
	local commit="$1"

	if git branch | grep -wq staging-updates ; then
		git checkout staging-updates
	else
		git checkout -b staging-updates
	fi

	git cherry-pick $commit
}

push_branches_to_own_remote() {
       local $pkg="$1"

       [ -n "$OWN_REMOTE" ] || return 0

       for branch in $pkg-update staging-updates ; do
	       git push -u "$OWN_REMOTE" "$branch"
       done
}

pkg="$1"
ver="$2"

pushd "$PACKAGES_REPO"

check_only_one_pkg "$pkg" || {
	popd
	exit 1
}

makefile=$(package_get_makefile "$pkg")

[ -n "$makefile" ] || {
	echo_red "Weird: not makefile found for '$pkg'"
	exit 1
}

echo_green "Package makefile is: '$makefile'"

if package_is_python_package "$makefile" ; then

	echo_green "  Package is a Python package"

	if package_python_uses_pypi_mk "$makefile" ; then
		echo_green "  Using PYPI_NAME field for package name"
		pkg_name=$(package_python_get_pypi_name "$makefile")
		if [ "$pkg_name" == '$(PKG_NAME)' ] ; then
			pkg_name=$(package_get_pkg_name "$makefile")
		fi
	else
		echo_green "  Using PKG_NAME field for package name"
		pkg_name=$(package_get_pkg_name "$makefile")
	fi

	[ -n "$pkg_name" ] || {
		echo_red "Could not get package name from '$makefile'"
		exit 1
	}

	echo_green "  Package name is '$pkg_name'"

	download_python_get_hash "$pkg_name" "$ver" pkg_hash

	[ -n "$pkg_hash" ] || {
		echo_red "Could not get package name for '$pkg:$ver'"
		exit 1
	}

	sed "s/PKG_VERSION.*/PKG_VERSION:=${ver}/g" -i "$makefile"
	sed "s/PKG_HASH.*/PKG_HASH:=${ver}/g" -i "$makefile"
	sed "s/PKG_RELEASE.*/PKG_RELEASE:=1/g" -i "$makefile"

	owrt_repo_update

	do_update_and_commit "$makefile" "$pkg_name" "$ver" "$pkg_hash"
	commit=$(git rev-parse HEAD)

	do_cherry_pick_to_staging "$commit"

	push_branches_to_own_remote "$pkg"
else
	echo_red "Non-python package support not implemented yet"
	exit 1
fi

popd
