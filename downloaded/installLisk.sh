#!/bin/bash
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

# Variable Declaration
UNAME=$(uname)-$(uname -m)
DEFAULT_LISK_LOCATION=$(pwd)
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
if [ "$USER" == "root" ]; then
	echo "Error: Lisk should not be installed be as root. Exiting."
	exit 1
fi

prereq_checks() {
	echo -e "Checking prerequisites:"

	if [ -x "$(command -v curl)" ]; then
		echo -e "curl is installed.\\t\\t\\t\\t\\t$(tput setaf 2)Passed$(tput sgr0)"
	else
		echo -e "\\ncurl is not installed.\\t\\t\\t\\t\\t$(tput setaf 1)Failed$(tput sgr0)"
			echo -e "\\nPlease follow the Prerequisites at: https://docs.lisk.io/docs/core-pre-installation-binary"
		exit 2
	fi

	if [ -x "$(command -v tar)" ]; then
		echo -e "Tar is installed.\\t\\t\\t\\t\\t$(tput setaf 2)Passed$(tput sgr0)"
	else
		echo -e "\\ntar is not installed.\\t\\t\\t\\t\\t$(tput setaf 1)Failed$(tput sgr0)"
			echo -e "\\nPlease follow the Prerequisites at: https://docs.lisk.io/docs/core-pre-installation-binary"
		exit 2
	fi

	if [ -x "$(command -v wget)" ]; then
		echo -e "Wget is installed.\\t\\t\\t\\t\\t$(tput setaf 2)Passed$(tput sgr0)"
	else
		echo -e "\\nWget is not installed.\\t\\t\\t\\t\\t$(tput setaf 1)Failed$(tput sgr0)"
		echo -e "\\nPlease follow the Prerequisites at: https://docs.lisk.io/docs/core-pre-installation-binary"
		exit 2
	fi

	echo -e "$(tput setaf 2)All preqrequisites passed!$(tput sgr0)"
}

# Adding LC_ALL LANG and LANGUAGE to user profile
# shellcheck disable=SC2143
if [[ -f ~/.bash_profile && ! "$(grep "en_US.UTF-8" ~/.bash_profile)" ]]; then
	{ echo "LC_ALL=en_US.UTF-8";  echo "LANG=en_US.UTF-8";  echo "LANGUAGE=en_US.UTF-8"; } >> ~/.profile

elif [[ -f ~/.bash_profile && ! "$(grep "en_US.UTF-8" ~/.bash_profile)" ]]; then
	{ echo "LC_ALL=en_US.UTF-8";  echo "LANG=en_US.UTF-8";  echo "LANGUAGE=en_US.UTF-8"; } >> ~/.bash_profile
fi

user_prompts() {
	[ "$LISK_LOCATION" ] || read -r -p "Where do you want to install Lisk to? (Default $DEFAULT_LISK_LOCATION): " LISK_LOCATION
	LISK_LOCATION=${LISK_LOCATION:-$DEFAULT_LISK_LOCATION}
	if [[ ! -r "$LISK_LOCATION" ]]; then
		echo "$LISK_LOCATION is not valid, please check and re-execute"
		exit 2;
	fi

	[ "$RELEASE" ] || read -r -p "Would you like to install the Main or Test Client? (Default $DEFAULT_RELEASE): " RELEASE
	RELEASE=${RELEASE:-$DEFAULT_RELEASE}
	if [[ ! "$RELEASE" == "main" && ! "$RELEASE" == "test" && ! "$RELEASE" == "dev" && ! "$RELEASE" == "beta" ]]; then
		echo "$RELEASE is not valid, please check and re-execute"
		exit 2;
	fi

	[ "$SYNC" ] || read -r -p "Would you like to synchronize from the Genesis Block? (Default $DEFAULT_SYNC): " SYNC
	SYNC=${SYNC:-$DEFAULT_SYNC}
	if [[ ! "$SYNC" == "no" && ! "$SYNC" == "yes" ]]; then
		echo "$SYNC is not valid, please check and re-execute"
		exit 2;
	fi
	LISK_INSTALL="$LISK_LOCATION"'/lisk-'"$RELEASE"
}

download_lisk() {
	if [[ "$LOCAL_TAR" ]]; then
		echo -e "\\nUsing local binary $LOCAL_TAR"
		LISK_VERSION="$LOCAL_TAR"
		readarray LISK_DIR_A < <(tar -tf "$LISK_VERSION" | cut -d '/' -f 1 | sort -u | tr -d '\n')
		if [[ ${#LISK_DIR_A[@]} != 1 ]]; then
			echo -e "\\nMalformed binary, aborting..."
			exit 1
		fi
		LISK_DIR="${LISK_DIR_A[0]}"
		return
	fi

	LISK_VERSION=lisk-$UNAME.tar.gz

	LISK_DIR=$(echo "$LISK_VERSION" | cut -d'.' -f1)

	rm -f "$LISK_VERSION" "$LISK_VERSION".SHA256 &> /dev/null

	echo -e "\\nDownloading current Lisk binaries: ""$LISK_VERSION"

	curl --progress-bar -o "$LISK_VERSION" "https://downloads.lisk.io/lisk/$RELEASE/$LISK_VERSION"

	curl -s "https://downloads.lisk.io/lisk/$RELEASE/$LISK_VERSION.SHA256" -o "$LISK_VERSION".SHA256

	if [[ "$(uname)" == "Linux" ]]; then
		SHA256=$(sha256sum -c "$LISK_VERSION".SHA256 | awk '{print $2}')
	elif [[ "$(uname)" == "Darwin" ]]; then
		SHA256=$(shasum -a 256 -c "$LISK_VERSION".SHA256 | awk '{print $2}')
	fi

	if [[ "$SHA256" == "OK" ]]; then
		echo -e "\\nChecksum Passed!"
	else
		echo -e "\\nChecksum Failed, aborting installation"
		rm -f "$LISK_VERSION" "$LISK_VERSION".SHA256
		exit 0
	fi
}

install_lisk() {
	echo -e '\nExtracting Lisk binaries to '"$LISK_INSTALL"

	tar -xzf "$LISK_VERSION" -C "$LISK_LOCATION"

	mv "$LISK_LOCATION/$LISK_DIR" "$LISK_INSTALL"

	# if user is specifying a binary, we probably don't want to delete it
	if [[ ! $LOCAL_TAR ]]; then
		echo -e "\\nCleaning up downloaded files"
		rm -f "$LISK_VERSION" "$LISK_VERSION".SHA256
	fi
}

configure_lisk() {
	cd "$LISK_INSTALL" || exit 2

	echo -e "\\nColdstarting Lisk for the first time"
	if ! bash lisk.sh coldstart -f "$LISK_INSTALL"/var/db/blockchain.db.gz; then
		echo "Installation failed. Cleaning up..."
		cleanup_installation
	fi

	sleep 5 # Allow the DApp password to generate and write back to the config.json

	echo -e "\\nStopping Lisk to perform database tuning"
	bash lisk.sh stop

	echo -e "\\nExecuting database tuning operation"
	bash tune.sh
}

cleanup_installation() {
	echo -e "\\nStopping Lisk components before cleanup"
	bash lisk.sh stop

	cd ../ || exit 2

	if [[ ! $LOCAL_TAR ]]; then
		echo -e "\\nRemoving Lisk directory and installation files"
		rm -rf "$LISK_INSTALL"
		rm -f "$LISK_VERSION" "$LISK_VERSION".SHA256
	fi

	if [[ "$FRESH_INSTALL" == false ]]; then
		echo -e "Restoring old Lisk installation"
		cp "$LISK_BACKUP" "$LISK_INSTALL"
		bash "$LISK_INSTALL/lisk.sh" start
	fi

	echo -e "\\nPlease check installLisk.out for more details on the failure. See here for troubleshooting steps: https://docs.lisk.io/docs/core-troubleshooting"
	echo -e "\\nIf no steps resolve your issue, please log an issue at: https://github.com/LiskHQ/lisk-build/issues"
	exit 1
}

backup_lisk() {
	echo -e "\\nStopping Lisk to perform a backup"
	cd "$LISK_INSTALL" || exit 2
	bash lisk.sh stop

	echo -e "\\nCleaning up PM2"
	bash lisk.sh cleanup

	echo -e "\\nBacking up existing Lisk Folder"

	LISK_BACKUP="$LISK_LOCATION"'/backup/lisk-'"$RELEASE"
	LISK_OLD_PG="$LISK_BACKUP"'/pgsql/'
	LISK_NEW_PG="$LISK_INSTALL"'/pgsql/'

	if [[ -d "$LISK_BACKUP" ]]; then
		echo -e "\\nRemoving old backup folder"
		rm -rf "$LISK_BACKUP" &> /dev/null
	fi

	mkdir -p "$LISK_LOCATION"/backup/ &> /dev/null
	mv -f "$LISK_INSTALL" "$LISK_LOCATION"/backup/ &> /dev/null
	cd "$LISK_LOCATION" || exit 2
}

start_lisk() { # Parse the various startup flags
	if [[ "$REBUILD" == true ]]; then
		if [[ "$URL" ]]; then
			echo -e "\\nStarting Lisk with specified snapshot"
			cd "$LISK_INSTALL" || exit 2
			bash lisk.sh rebuild -u "$URL"
		else
			echo -e "\\nStarting Lisk with official snapshot"
			cd "$LISK_INSTALL" || exit 2
			bash lisk.sh rebuild
		fi
	elif [[ "$FRESH_INSTALL" == true && "$SYNC" == "no" ]]; then
		echo -e "\\nStarting Lisk with official snapshot"
		cd "$LISK_INSTALL" || exit 2
		bash lisk.sh rebuild
	else
		if [[ "$SYNC" == "yes" ]]; then
				echo -e "\\nStarting Lisk from genesis"
				bash lisk.sh rebuild -f var/db/blockchain.db.gz
		 else
			 echo -e "\\nStarting Lisk with current blockchain"
			 cd "$LISK_INSTALL" || exit 2
			 bash lisk.sh start
		fi
	fi
}

upgrade_lisk() {
	echo -e "\\nRestoring Database to new Lisk Install"
	mkdir -m700 "$LISK_INSTALL"/pgsql/data

	if [[ "$("$LISK_OLD_PG"/bin/postgres -V)" != "postgres (PostgreSQL) 9.6".* ]]; then
		echo -e "\\nUpgrading database from PostgreSQL 9.5 to PostgreSQL 9.6"
		# Disable SC1090 - Its unable to resolve the file but we know its there.
		# shellcheck disable=SC1090
		. "$LISK_INSTALL"/shared.sh
		# shellcheck disable=SC1090
		. "$LISK_INSTALL"/env.sh
		# shellcheck disable=SC2129
		pg_ctl initdb -D "$LISK_NEW_PG"/data &> $LOG_FILE
		# shellcheck disable=SC2129
		"$LISK_NEW_PG"/bin/pg_upgrade -b "$LISK_OLD_PG"/bin -B "$LISK_NEW_PG"/bin -d "$LISK_OLD_PG"/data -D "$LISK_NEW_PG"/data &> $LOG_FILE
		bash "$LISK_INSTALL"/lisk.sh start_db &> $LOG_FILE
		bash "$LISK_INSTALL"/analyze_new_cluster.sh &> $LOG_FILE
		rm -f "$LISK_INSTALL"/*cluster*
	else
		cp -rf "$LISK_OLD_PG"/data/* "$LISK_NEW_PG"/data/
	fi

	echo -e "\\nCopying config.json entries from previous installation"
	"$LISK_INSTALL"/bin/node "$LISK_INSTALL"/updateConfig.js -o "$LISK_BACKUP"/config.json -n "$LISK_INSTALL"/config.json
}

usage() {
	echo "Usage: $0 <install|upgrade> [-d <directory] [-r <main|test|dev>] [-n] [-h [-u <URL>] ] "
	echo "install         -- install Lisk"
	echo "upgrade         -- upgrade Lisk"
	echo " -d <DIRECTORY> -- install location"
	echo " -r <RELEASE>   -- choose main or test"
	echo " -h             -- rebuild instead of copying database"
	echo " -u <URL>       -- URL to rebuild from - Requires -h"
	echo " -0 <yes|no>    -- Forces sync from 0"
}

parse_option() {
	OPTIND=2
	while getopts :d:f:r:u:h0: OPT; do
		 # shellcheck disable=SC2220
		 case "$OPT" in
			 d) LISK_LOCATION="$OPTARG" ;;
			 f) LOCAL_TAR="$OPTARG" ;;
			 r) RELEASE="$OPTARG" ;;
			 h) REBUILD=true ;;
			 u) URL="$OPTARG" ;;
			 0) SYNC="$OPTARG" ;;
		 esac
	 done

 if [ "$SYNC" ]; then
		if [[ "$SYNC" != "no" && "$SYNC" != "yes" ]]; then
			echo "-0 <yes|no>"
			usage
			exit 1
		fi
	fi

	if [ "$RELEASE" ]; then
		if [[ "$RELEASE" != test && "$RELEASE" != "main" && "$RELEASE" != "dev" && "$RELEASE" != "beta" ]]; then
			echo "-r <test|main|dev|beta>"
			usage
			exit 1
		fi
	fi
}

case "$1" in
"install")
	FRESH_INSTALL='true'
	parse_option "$@"
	prereq_checks
	user_prompts
	download_lisk
	install_lisk
	configure_lisk
	start_lisk
	;;
"upgrade")
	FRESH_INSTALL='false'
	parse_option "$@"
	user_prompts
	download_lisk
	backup_lisk
	install_lisk
	upgrade_lisk
	start_lisk
	;;
*)
	echo "Error: Unrecognized command."
	echo ""
	echo "Available commands are: install upgrade"
	usage
	exit 1
	;;
esac
