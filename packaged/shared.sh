#!/bin/bash
#
# LiskHQ/lisk-scripts/shared.sh
# Copyright (C) 2017 Lisk Foundation
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
######################################################################

bail() {
	echo "Error executing command, exiting"
	exit 1
}

exec_cmd_nobail() {
	echo "+ $1"
	bash -c "$1"
}

exec_cmd() {
	exec_cmd_nobail "$1" || bail
}

check_cmds() {
	local cmds=("${!1}")
	for i in "${cmds[@]}"; do
		command -v "$i" > /dev/null 2>&1 || {
			echo "Error: $i command was not found. Aborting." >&2; exit 1;
		}
	done
}

function get_lisk_app_name() {
	local PM2_CONFIG=$1
	PM2_APP="$( jq .apps[0].name -r "$PM2_CONFIG" )"
	echo "$PM2_APP"
}

function get_lisk_custom_config() {
	local PM2_CONFIG=$1
	local REGEXP="-c ([^ ]+)"
	PM2_APP_ARGS="$( jq .apps[0].args -r "$PM2_CONFIG" )"
	if [[ "$PM2_APP_ARGS" =~ $REGEXP ]]; then
		LISK_CUSTOM_CONFIG="${BASH_REMATCH[1]}"
	else
		LISK_CUSTOM_CONFIG=/dev/null
	fi
	echo "$LISK_CUSTOM_CONFIG"
}
