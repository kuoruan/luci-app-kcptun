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

[ -z "$KCPTUN" ] && KCPTUN=kcptun

if [ -r ${IPKG_INSTROOT}/usr/share/libubox/jshn.sh ]; then
	. ${IPKG_INSTROOT}/usr/share/libubox/jshn.sh
elif [ -r ${IPKG_INSTROOT}/lib/functions/jshn.sh ]; then
	. ${IPKG_INSTROOT}/lib/functions/jshn.sh
else
	logger -p daemon.err -t "$KCPTUN" \
		"Package jshn is required, please install first."
	exit 1
fi

_log() {
	local msg="$1"

	if is_enable_logging; then
		echo "[INFO] $(date '+%Y/%m/%d %T') $msg" >>"${log_folder}/event.log"
	else
		logger -p daemon.info -t "$KCPTUN" "$msg"
	fi
}

_err() {
	local msg="$1"

	if is_enable_logging; then
		echo "[ERROR] $(date '+%Y/%m/%d %T') $msg" >>"${log_folder}/event.log"
	else
		logger -p daemon.err -t "$KCPTUN" "$msg"
	fi
}

uci_get_by_type_option(){
	local type="$1"
	local option="$2"
	local default="$3"

	local ret
	ret="$(uci -q get ${KCPTUN}.@${type}[-1].${option})"
	echo "${ret:=$default}"
}

is_enable_logging() {
	local retval=1
	if [ -z "$enable_logging" ]; then
		enable_logging=$(uci_get_by_type_option "general" "enable_logging" "0")
	fi

	if [ ."$enable_logging" = ."1" ]; then
		retval=0
		if [ -z "$log_folder" ]; then
			log_folder=$(uci_get_by_type_option "general" "log_folder" "/var/log/$KCPTUN")
		fi
	fi

	return $retval
}

validate_client_file() {
	local file="$1"

	if [ ! -f "$file" ]; then
		return 1
	fi

	[ -x "$file" ] || chmod +x "$file"

	( $file -v | grep -q "$KCPTUN" )
}

get_content() {
	local url="$1"
	local retry=0

	local content=
	get_network_content() {
		if [ $retry -ge 3 ]; then
			return 1
		fi

		content="$(/usr/bin/wget -t 1 -T 5 -qO- --no-check-certificate "$url")"

		if [ "$?" != "0" ] || [ -z "$content" ]; then
			retry=$(expr $retry + 1)
			_err "Get content of url ${url} failed."
			_err "Auto retry in 3 seconds."
			sleep 3
			get_network_content
		fi
	}

	get_network_content
	echo "$content"
}

download_file() {
	local url="$1"
	local file="$2"
	local retry=0

	download_file_to_path() {
		if [ $retry -ge 3 ]; then
			rm -f "$file"
			return 1
		fi

		if ! ( /usr/bin/wget -t 1 -T 5 -qO "$file" --no-check-certificate "$url" ); then
			retry=$(expr $retry + 1)
			_err "Download url ${url} failed."
			_err "Auto retry in 3 seconds..."
			sleep 3
			download_file_to_path
		fi
	}

	download_file_to_path
}
