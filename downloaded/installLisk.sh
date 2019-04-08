#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
#
# LiskHQ/lisk-scripts/installLisk.sh
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

# VERSION 0.7.1

# Variable Declaration
DEFAULT_LISK_LOCATION=$( pwd )
DEFAULT_RELEASE=main
DEFAULT_SYNC=no
LOG_FILE=installLisk.out

# Setup logging
exec > >(tee -ia $LOG_FILE)
exec 2>&1

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# Verification Checks
if [ $UID -eq 0 ]; then
	echo "Error: $0 should not be run as root. Exiting."
	exit 1
fi

prereq_checks() {
	if [ "$OSTYPE" != "linux-gnu" ] || [ "$HOSTTYPE" != "x86_64" ]; then
		echo "Error: only Linux (x86_64) is supported."
		exit 2
	fi
	if ! command -v curl &>/dev/null; then
		echo "Error: curl is not installed. Exiting."
		exit 2
	fi
	if ! command -v tar &>/dev/null; then
		echo "Error: tar is not installed. Exiting."
		exit 2
	fi

	if command -v ss &>/dev/null ; then
		PORT_5432_IN_USE=$(ss --tcp --numeric --listening | grep --count 'LISTEN.*:5432 ' || true)
	else
		PORT_5432_IN_USE=$(netstat --tcp --numeric --listening | grep --count ':5432 .*LISTEN' || true)
	fi
	IGNORE_WARNING=${IGNORE_WARNING:-"false"}
	if [[ $FRESH_INSTALL == "true" && $PORT_5432_IN_USE -gt 0 && "$IGNORE_WARNING" == "false" ]] ; then
		echo "Error: A process is already listening on port 5432"
		echo "PostgreSQL by default listens on 127.0.0.1:5432 and attempting to run two instances at the same time will result in this installation failing"
		echo "To proceed anyway, use the -i flag to ignore warning"
		exit 2
	fi
}

user_prompts() {
	[ "${LISK_LOCATION:-}" ] || read -r -p "Where do you want to install Lisk to? (Default $DEFAULT_LISK_LOCATION): " LISK_LOCATION
	LISK_LOCATION=${LISK_LOCATION:-$DEFAULT_LISK_LOCATION}
	if [[ ! -r "$LISK_LOCATION" ]]; then
		echo "$LISK_LOCATION is not valid, please check and re-execute"
		exit 2;
	fi

	[ "${RELEASE:-}" ] || read -r -p "Would you like to install the Main or Test Client? (Default $DEFAULT_RELEASE): " RELEASE
	RELEASE=${RELEASE:-$DEFAULT_RELEASE}
	if [ "$RELEASE" != "main" ] && [ "$RELEASE" != "test" ] && [ "$RELEASE" != "beta" ]; then
		echo "$RELEASE is not valid, please check and re-execute"
		exit 2;
	fi

	[ "${SYNC:-}" ] || read -r -p "Would you like to synchronize from the Genesis Block? (Default $DEFAULT_SYNC): " SYNC
	SYNC=${SYNC:-$DEFAULT_SYNC}
	if [ "$SYNC" != "no" ] && [ "$SYNC" != "yes" ]; then
		echo "$SYNC is not valid, please check and re-execute"
		exit 2;
	fi
	LISK_INSTALL="$LISK_LOCATION/lisk-$RELEASE"
}

download_lisk() {
	if [[ -n "$LOCAL_TAR" ]]; then
		echo "Using local binary $LOCAL_TAR"
		LISK_VERSION="$LOCAL_TAR"
		LISK_DIR=${LISK_VERSION%.tar.gz}
		return
	fi

	if [ -z "$LISK_VERSION_NUMBER" ] ; then
		echo "Getting latest lisk version"
		LISK_VERSION_NUMBER=$(curl --silent --fail "https://downloads.lisk.io/lisk/$RELEASE/latest.txt")
	fi
	LISK_VERSION=lisk-$LISK_VERSION_NUMBER-Linux-x86_64.tar.gz
	LISK_DIR=${LISK_VERSION%.tar.gz}

	rm -f "$LISK_VERSION"{,.SHA256}

	echo "Downloading current Lisk binaries: $LISK_VERSION"
	curl --progress-bar --fail "https://downloads.lisk.io/lisk/$RELEASE/$LISK_VERSION_NUMBER/$LISK_VERSION" --output "$LISK_VERSION"
	curl --silent --fail "https://downloads.lisk.io/lisk/$RELEASE/$LISK_VERSION_NUMBER/$LISK_VERSION.SHA256" --output "$LISK_VERSION.SHA256"

	if sha256sum -c "$LISK_VERSION.SHA256"; then
		echo "Checksum verfication succeeded."
	else
		echo "Error: checksum verification failed. Exiting."
		rm -f "$LISK_VERSION"{,.SHA256}
		exit 3
	fi
}

install_lisk() {
	echo "Extracting Lisk binaries to $LISK_INSTALL"

	tar xf "$LISK_VERSION" -C "$LISK_LOCATION"
	mv "$LISK_LOCATION/$LISK_DIR" "$LISK_INSTALL"

	sed -i -r -e "s/^(export LISK_NETWORK=).*/\\1${RELEASE}net/" "$LISK_INSTALL/env.sh"

	# if user is specifying a tarball, we probably don't want to delete it
	if [[ -z "$LOCAL_TAR" ]]; then
		echo "Cleaning up downloaded files"
		rm -f "$LISK_VERSION"{,.SHA256}
	fi
}

configure_lisk() {
	echo "Coldstarting Lisk for the first time"
	if ! "$LISK_INSTALL/lisk.sh" coldstart -f "$LISK_INSTALL/var/db/blockchain.db.gz"; then
		echo "Installation failed. Cleaning up..."
		cleanup_installation
	fi

	echo "Stopping Lisk to perform database tuning"
	"$LISK_INSTALL/lisk.sh" stop

	echo "Executing database tuning operation"
	( cd "$LISK_INSTALL"; ./tune.sh )
}

cleanup_installation() {
	echo "Stopping Lisk components before cleanup"
	"$LISK_INSTALL/lisk.sh" stop

	echo "Removing Lisk directory"
	rm -rf "$LISK_INSTALL"
	if [[ -z "$LOCAL_TAR" ]]; then
		echo "Removing installation files"
		rm -f "$LISK_VERSION"{,.SHA256}
	fi

	if [[ "$FRESH_INSTALL" == false ]]; then
		echo "Restoring old Lisk installation"
		cp "$LISK_BACKUP" "$LISK_INSTALL"
		"$LISK_INSTALL/lisk.sh" start
	fi

	echo "Please check installLisk.out for more details on the failure."
	echo "See troubleshooting steps at https://lisk.io/documentation/lisk-core/troubleshooting"
	echo "If no steps resolve your issue, please create an issue at https://github.com/LiskHQ/lisk-scriptsissues"
	exit 4
}

backup_lisk() {
	echo "Stopping Lisk to perform a backup"
	"$LISK_INSTALL/lisk.sh" stop
	"$LISK_INSTALL/lisk.sh" cleanup

	echo "Backing up existing Lisk directory"
	LISK_BACKUP="$LISK_LOCATION/backup/lisk-$RELEASE"
	LISK_OLD_PG="$LISK_BACKUP/pgsql/"
	LISK_NEW_PG="$LISK_INSTALL/pgsql/"

	rm -rf "$LISK_BACKUP"
	mkdir -p "$LISK_LOCATION/backup/"
	mv -f "$LISK_INSTALL" "$LISK_BACKUP"
}

start_lisk() { # Parse the various startup flags
	cd "$LISK_INSTALL" || exit 2
	if [[ "$REBUILD" == "true" ]]; then
		if [[ -z "$URL" ]]; then
			echo "Starting Lisk with official snapshot"
			bash lisk.sh rebuild
		else
			echo "Starting Lisk with specified snapshot"
			bash lisk.sh rebuild -u "$URL"
		fi
	elif [[ "$FRESH_INSTALL" == true && "$SYNC" == "no" ]]; then
		echo "Starting Lisk with official snapshot"
		bash lisk.sh rebuild
	else
		if [[ "$SYNC" == "yes" ]]; then
			echo "Starting Lisk from genesis"
			bash lisk.sh rebuild -f var/db/blockchain.db.gz
		else
			echo "Starting Lisk with current blockchain"
			bash lisk.sh start
		fi
	fi
}

upgrade_lisk() {
	echo "Restoring Database to new Lisk Install"
	mkdir --mode=0700 "$LISK_INSTALL/pgsql/data"

	if [[ "$( "$LISK_OLD_PG/bin/postgres" -V )" != "postgres (PostgreSQL) 10".* ]]; then
		set +u
		# shellcheck disable=SC1090
		. "$LISK_INSTALL/env.sh"
		set -u
		# shellcheck disable=SC1090
		. "$LISK_INSTALL/shared.sh"
		pg_ctl initdb -D "$LISK_NEW_PG/data" &>>$LOG_FILE
		ABS_LOG_FILE="$( pwd )/$LOG_FILE"
		TEMP=$( mktemp -d )
		pushd "$TEMP" >/dev/null || exit 2
		LD_LIBRARY_PATH="$LISK_OLD_PG/lib:${LD_LIBRARY_PATH:-}" "$LISK_NEW_PG/bin/pg_upgrade" -b "$LISK_OLD_PG/bin" -B "$LISK_NEW_PG/bin" -d "$LISK_OLD_PG/data" -D "$LISK_NEW_PG/data" &>>"$ABS_LOG_FILE"
		popd >/dev/null || exit 2
		bash "$LISK_INSTALL/lisk.sh" start_db &>>$LOG_FILE
		bash "$TEMP/analyze_new_cluster.sh" &>>$LOG_FILE
		rm -f "$TEMP/"{analyze_new,delete_old}_cluster.sh
		rmdir "$TEMP"
	else
		cp -rf "$LISK_OLD_PG/data/"* "$LISK_NEW_PG/data/"
	fi

	echo "Copying config.json entries from previous installation"
	OLD_VERSION=$( "$LISK_INSTALL/bin/jq" --raw-output .version "$LISK_BACKUP/package.json" )
	"$LISK_INSTALL/bin/node" "$LISK_INSTALL/scripts/update_config.js" --network "${RELEASE}net" --output "$LISK_INSTALL/config.json" "$LISK_BACKUP/config.json" "$OLD_VERSION"
}

usage() {
	echo "Usage: $0 <install|upgrade> [-d <DIRECTORY>] [-f <FILE>] [-r <main|test|beta>] [-n] [-h [-u <URL>]] [-0 <yes|no>] [-s <LISK_VERSION_NUMBER>]"
	echo "install             -- install Lisk"
	echo "upgrade             -- upgrade Lisk"
	echo " -d <DIRECTORY>     -- install location"
	echo " -f <FILE>          -- use a local tarball to install"
	echo " -r <main|test|beta> -- choose network (default: main)"
	echo " -h                 -- rebuild instead of copying database"
	echo " -i                 -- ignore warning"
	echo " -u <URL>           -- URL to rebuild from - Requires -h"
	echo " -0 <yes|no>        -- force sync from 0 (default: no)"
	echo " -s <LISK_VERSION_NUMBER>  -- specify a version of lisk-core. ex: -s 1.0.2. By default, the latest version will be installed"
}

parse_option() {
	# defaults
	LOCAL_TAR=""
	IGNORE_WARNING="false"
	REBUILD="false"
	URL=""
	LISK_VERSION_NUMBER=""
	#
	LISK_MASTER_PASSWORD=${LISK_MASTER_PASSWORD:-""}

# LISK_LOCATION, RELEASE, SYNC

	OPTIND=2
	while getopts :d:f:r:u:s:hi0: OPT; do
		# shellcheck disable=SC2220
		case "$OPT" in
			d) LISK_LOCATION="$OPTARG" ;;
			f) LOCAL_TAR="$OPTARG" ;;
			r) RELEASE="$OPTARG" ;;
			h) REBUILD="true" ;;
			i) IGNORE_WARNING="true" ;;
			u) URL="$OPTARG" ;;
			0) SYNC="$OPTARG" ;;
			s) LISK_VERSION_NUMBER="$OPTARG" ;;
		esac
	done

	if [ -n "${SYNC:-}" ]; then
		if [ "$SYNC" != "no" ] && [ "$SYNC" != "yes" ]; then
			usage
		fi
	fi
	if [ -n "${RELEASE:-}" ]; then
		if [ "$RELEASE" != "main" ] && [ "$RELEASE" != "test" ] && [ "$RELEASE" != "beta" ]; then
			usage
		fi
	fi

	LISK_INSTALL="${LISK_LOCATION:-$DEFAULT_LISK_LOCATION}/lisk-${RELEASE:-$DEFAULT_RELEASE}"
}

case "$1" in
"install")
	FRESH_INSTALL="true"
	parse_option "$@"
	prereq_checks
	user_prompts
	download_lisk
	install_lisk
	configure_lisk
	start_lisk
	;;
"upgrade")
	FRESH_INSTALL="false"
	parse_option "$@"
	prereq_checks
	user_prompts
	download_lisk
	backup_lisk
	install_lisk
	upgrade_lisk
	start_lisk
	;;
*)
	usage
	exit 1
	;;
esac
