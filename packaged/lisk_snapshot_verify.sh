#!/bin/bash
#
# LiskHQ/lisk-scripts/lisk_snapshot_verify.sh
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
DB_NAME="lisk_verify"

function clean_up {
	RET_CODE=$?
	dropdb $DB_NAME --if-exists
	rm -f verify.json
	exit $RET_CODE
}

trap clean_up EXIT

if [ "$USER" == "root" ]; then
	echo "Error: $0 should not be run be as root. Exiting."
	exit 1
fi

if [[ ! $1 ]] ; then
	echo -e 'Error: snapshot is required'
	echo -e "Usage: $0 <PATH_TO_SNAPSHOT>\\n"
	echo -e "Example: $0 backups/lisk_main_backup-8675309.gz"
	exit 1;
else
	DB_SNAPSHOT="$1"
fi

cd "$(cd -P -- "$(dirname -- "$0")" && pwd -P)" || exit 2
# shellcheck source=shared.sh
. "$PWD/shared.sh"
# shellcheck source=env.sh
. "$PWD/env.sh"

if [ ! -f "$PWD/app.js" ]; then
	echo "Error: Lisk installation was not found. Exiting."
	exit 1
fi

jq '.db.database="'$DB_NAME'"' config.json > verify.json.1
jq '.httpPort=12050' verify.json.1 > verify.json.2
jq '.wsPort=12051' verify.json.2 > verify.json.3
jq '.logFileName="logs/lisk_verify.log"' verify.json.3 > verify.json.4
jq '.fileLogLevel="info"' verify.json.4 > verify.json

rm -f verify.json.*

echo 'Importing blockchain with '"$DB_SNAPSHOT"' to lisk_verify db'

createdb $DB_NAME
if ! gunzip -fcq "$DB_SNAPSHOT" | psql -q -U "$USER" -d "$DB_NAME" >> logs/lisk.verify.out 2>&1; then
	echo "Failed to import blockchain."
	exit 1
else
	echo "Blockchain imported successfully."
fi

DB_HEIGHT="$(psql -d "$DB_NAME" -t -p "$DB_PORT" -c 'select height from blocks order by height desc limit 1;')"

echo "Starting verification"
bash lisk.sh start -p etc/pm2-verify.json

COUNT=0
echo -n "Checking Block Height..."

while [[ $COUNT -lt 24 ]]; do
	sleep 5
	DB_HEIGHT2="$(psql -d "$DB_NAME" -t -p "$DB_PORT" -c 'select height from blocks order by height desc limit 1;')"
	if [[ $DB_HEIGHT -lt $DB_HEIGHT2 ]]; then
		break
	else
		echo -n "."
	fi
	(( COUNT+=1 ))
done
echo

bash lisk.sh stop_node -p etc/pm2-verify.json

if [[ $DB_HEIGHT -ge $DB_HEIGHT2 ]]; then
	echo -e 'Snapshot fails verification. Current Block Height:'"$DB_HEIGHT2"
	exit 1
else
	echo 'Snapshot passes verification. Current Block Height:'"$DB_HEIGHT2"
fi
