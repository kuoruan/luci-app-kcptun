#!/bin/sh
#
# Copyright 2016-2017 Xingwang Liao <kuoruan@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

KCPTUN=kcptun
LATEST_KCPTUN_API='https://api.github.com/repos/xtaci/kcptun/releases/latest'
BASE_DOWNLOAD_URL='https://github.com/xtaci/kcptun/releases/download'
LATEST_FILE=/usr/lib/kcptun/KCPTUN_LATEST

if [ -r /usr/lib/kcptun/functions.sh ]; then
	. /usr/lib/kcptun/functions.sh
else
	logger -p daemon.err -t "$KCPTUN" \
		"Could not find '/usr/lib/kcptun/functions.sh', please reinstall LuCI."
	exit 1
fi

retval=0

determine_arch() {
	arch="$(uname -m)"
	if [ ."$arch" = ."mips" ]; then
		if [ -r /usr/lib/os-release ]; then
			. /usr/lib/os-release
		elif [ -r /etc/openwrt_release ]; then
			. /etc/openwrt_release
		fi

		if [ -n "$LEDE_BOARD" ]; then
			arch="${LEDE_BOARD%/*}"
		elif [ -n "$DISTRIB_TARGET" ]; then
			arch="${DISTRIB_TARGET%/*}"
		fi
	fi
}

determine_file_tree() {
	case "$arch" in
		i?86)
			file_tree="386"
			;;
		x86_64)
			file_tree="amd64"
			;;
		ramips)
			file_tree="mipsle"
			;;
		ar71xx)
			file_tree="mips"
			;;
		armv[5-8]|armv[5-8][lb])
			file_tree="arm"
			sub_version="$(echo "$arch" | grep -o '[5-8]')"
			;;
		*)
			;;
	esac
}

get_latest_kcptun_version() {
	arch="$1"
	[ -z "$arch" ] && determine_arch

	determine_file_tree

	if [ -z "$file_tree" ]; then
		_err "Can't determine ARCH, or ARCH not supported. Please select manually."
		retval=11
		return 1
	fi

	local json_string
	json_string="$(get_content ${LATEST_KCPTUN_API} | grep -v 'null,')"

	if [ -z "$json_string" ]; then
		_err "Can't get ${KCPTUN} version info. Please check your network connection."
		retval=12
		return 1
	fi

	json_init
	json_load "$json_string"

	local tag_name assets name browser_download_url
	json_get_vars html_url tag_name
	kcptun_version="$(echo $tag_name | sed 's/^v//')"

	if json_is_a assets array; then
		json_get_keys assets assets
		json_select assets

		for asset in $assets; do
			json_select "$asset"
			json_get_vars name browser_download_url

			if [ -n "$browser_download_url" ]; then
				if ( echo "$browser_download_url" | grep -qw "linux-$file_tree" ); then
					kcptun_download_url="$browser_download_url"
					break
				fi
			elif [ -n "$name" ] && [ -n "$tag_name" ]; then
				if ( echo "$name" | grep -qw "linux-$file_tree" ); then
					kcptun_download_url="${BASE_DOWNLOAD_URL}/${tag_name}/${name}"
					break
				fi
			fi

			json_select ..
		done
	fi

	echo "$kcptun_download_url" >"$LATEST_FILE"
	if [ -z "$kcptun_download_url" ]; then
		_err "Can't get latest ${KCPTUN} download url. Please retry later."
		retval=13
		return 1
	fi
}

check_kcptun() {
	get_latest_kcptun_version "$1"

	cat >&1 <<-EOF
		{
		    "code": ${retval},
		    "version": "$kcptun_version",
		    "html_url": "$html_url"
		}
	EOF
}

update_kcptun() {
	arch="$1"
	[ -z "$arch" ] && determine_arch

	determine_file_tree

	local url
	url="$(cat "$LATEST_FILE" | sed 's/[[:space:]]//g')"

	if [ -z "$url" ]; then
		_err "Can't find ${KCPTUN} download url in ${LATEST_FILE}."
		retval=21
		return 1
	fi

	local file_path extract_path client_file back_file new_file
	file_path="$(mktemp -q -u)"
	extract_path="$(mktemp -q -d)"
	client_file="$(uci_get_by_type_option "general" "client_file" "/usr/bin/kcptun_client")"

	clean_all() {
		rm -rf "$file_path" "$extract_path"
	}

	if [ ! -d "$extract_path" ]; then
		_err "Could not create file, insufficient disk space."
		retval=22
		return 1
	fi

	download_file "$url" "$file_path"

	if [ "$?" != "0" ]; then
		clean_all
		_err "Can't download ${KCPTUN} file. Please check your network connection."
		retval=23
		return 1
	fi

	(
		_log "Download ${KCPTUN} zip file success. Extracting..."
		tar -zxf "$file_path" -C "$extract_path"
	)

	if [ "$?" != "0" ]; then
		_err "Extract ${KCPTUN} zip file failed."
		_err "Make sure you have tar installed and have enough disk space."
		retval=24
		return 1
	fi

	new_file="$(ls "${extract_path}/client_linux_${file_tree}${sub_version}"* | head -n1)"
	[ -z "$new_file" ] && new_file="$(ls "${extract_path}/client"* | head -n1)"

	if [ -z "$new_file" ]; then
		clean_all
		_err "Can't find client file in ${KCPTUN} zip file."
		retval=25
		return 1
	elif ! ( validate_client_file "$new_file" ); then
		clean_all
		_err "The downloaded ${KCPTUN} file is not suitable for current device."
		_err "Please reselect ARCH."
		retval=26
		return 1
	fi

	if [ -f "$client_file" ]; then
		back_file="${client_file}.bak"
		mv -f "$client_file" "$back_file"
	fi

	(
		mkdir -p "$(dirname "$client_file")"
		mv -f "$new_file" "$client_file"
	)

	if [ "$?" != "0" ]; then
		clean_all
		[ -n "$back_file" ] && mv -f "$back_file" "$client_file"

		_err "Could not move file, insufficient disk space."
		retval=27
		return 1
	fi

	uci -q batch <<-EOF >/dev/null
		set ${KCPTUN}.@general[-1].client_file="$client_file"
		commit ${KCPTUN}
	EOF

	clean_all
	[ -n "$back_file" ] && rm -f "$back_file"
	_log "Update ${KCPTUN} success. New file is located at ${client_file}."
}

# update check
action=${1:-"check"}

case "$action" in
	check)
		check_kcptun "$2"
		;;
	update)
		update_kcptun $2
		;;
	*)
		echo "Usage $(basename $0) update|check [ARCH]"
		exit 1
		;;
esac

exit $retval
