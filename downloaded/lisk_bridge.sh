#!/bin/bash
#
# LiskHQ/lisk-scripts/lisk_bridge.sh
# Copyright (C) 2018 Lisk Foundation
#
# Connects source and target versions of Lisk in order to migrate
# gracefully between protocol changes.
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

set -eo pipefail

# Declare working variables
BRIDGE_NETWORK="main"

OPTIND=1
while getopts ":s:f:n:h:" OPT; do
	case "$OPT" in
		s) LISK_HOME="$OPTARG" ;;
		f) LOCAL_TAR="$OPTARG" ;;
		n) BRIDGE_NETWORK="$OPTARG" ;; # Which network is being bridged
		h) TARGET_HEIGHT="$OPTARG" ;; # What height to cut over at
		:) echo 'Missing argument for -'"$OPTARG" >&2;
		   SHOW_USAGE=1;;
		*) echo 'Unimplemented option: -'"$OPTARG">&2;
		   SHOW_USAGE=1 ;;
	esac
done
if [[ -z $TARGET_HEIGHT ]]; then
	echo 'Error: -h <BLOCKHEIGHT> must be specified'>&2
	SHOW_USAGE=1;
fi
if [[ $SHOW_USAGE ]]; then
	echo "Usage: $0 <-h <BLOCKHEIGHT>> [-s <DIRECTORY>] [-n <NETWORK>] "
	echo '-h <BLOCKHEIGHT> -- specify blockheight at which bridging will be initiated'
	echo '-f <TARBALL> -- Specify local tarball for destination release'
	echo '-s <DIRECTORY>   -- Lisk home directory'
	echo '-n <NETWORK>     -- choose main or test'
	echo -e '\nExample: bash lisk_bridge.sh -h 50000000 -n test -s /home/lisk/lisk-test'
	echo -e '\nUse LISK_MASTER_PASSWORD env variable if you want to do secrets migration in non-interactive mode'
	exit 1;
fi
if [[ ! $LISK_HOME ]]; then
	LISK_HOME="$HOME/lisk-$BRIDGE_NETWORK"
fi
JQ="$LISK_HOME/bin/jq"

LISK_CONFIG="$LISK_HOME/config.json"
PORT="$($JQ -r '.port' "$LISK_CONFIG" | tr -d '[:space:]')"

while true; do
	BLOCK_HEIGHT="$(curl -s http://localhost:"$PORT"/api/loader/status/sync | $JQ -r '.height' || echo -1 )"
	if [[ "$BLOCK_HEIGHT" -eq -1 ]]; then
		echo "Unable to get block height"
	else
		echo "Current Block Height: $BLOCK_HEIGHT"
	fi
	[[ "$BLOCK_HEIGHT" -lt "$TARGET_HEIGHT" ]] || break
	sleep 1
done
bash "$LISK_HOME/lisk.sh" stop

if [[ "$BLOCK_HEIGHT" -gt "$TARGET_HEIGHT" ]]; then
	echo "The block height ($BLOCK_HEIGHT) is above the cut off point. Please see migration guide for next steps"
	exit 1;
fi

wget "https://downloads.lisk.io/lisk/$BRIDGE_NETWORK/installLisk.sh"
if [[ $LOCAL_TAR ]]; then
	bash "$PWD/installLisk.sh" upgrade -r "$BRIDGE_NETWORK" -d "$PWD" -0 no -f "$LOCAL_TAR"
else
	bash "$PWD/installLisk.sh" upgrade -r "$BRIDGE_NETWORK" -d "$PWD" -0 no
fi
