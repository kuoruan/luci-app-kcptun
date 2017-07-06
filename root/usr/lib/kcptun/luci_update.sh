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
LUCI_LATEST_API='https://api.github.com/repos/kuoruan/luci-app-kcptun/releases/latest'

retval=0

if [ -r /usr/lib/kcptun/functions.sh ]; then
	. /usr/lib/kcptun/functions.sh
else
	logger -p daemon.err -t "$KCPTUN" \
		"Could not find '/usr/lib/kcptun/functions.sh', please reinstall LuCI."
	exit 1
fi

get_latest_luci_version() {
	local json_string
	json_string="$(get_content ${LUCI_LATEST_API} | grep -v "null,")"

	if [ -z "$json_string" ]; then
		_err "Can't get LuCI version info. Please check your network connection."
		retval=12
		return 1
	fi

	json_init
	json_load "$json_string"

	local tag_name
	html_url=
	json_get_vars html_url tag_name
	luci_version="$(echo $tag_name | sed 's/^v//')"
}

check_luci() {
	get_latest_luci_version

	cat >&1 <<-EOF
		{
		    "code": ${retval},
		    "version": "$luci_version",
		    "html_url": "$html_url"
		}
	EOF
}

# check
action=${1:-"check"}

case "$action" in
	check)
		check_luci
		;;
	*)
		echo "Usage $(basename $0) check"
		exit 1
		;;
esac

exit $retval
