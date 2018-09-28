# Lisk Scripts

This repository contains various `bash` and `node` scripts used to install and manage [Lisk](https://github.com/LiskHQ/lisk). These scripts were originally maintained within [Lisk Build](https://github.com/LiskHQ/lisk-build), but are now developed here for independent release management.

[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](http://www.gnu.org/licenses/gpl-3.0)

## Index

- **Downloaded** scripts hosted at https://downloads.lisk.io/:

  - `installLisk.sh`

    Installs or upgrades the official Lisk binary packages.

- **Packaged** scripts included in each [Lisk Build](https://github.com/LiskHQ/lisk-build):

  - `env.sh`

    Sets various environment variables used by other scripts.

  - `lisk_bridge.sh`

    Migrates a Lisk installation from one version to the next, acting as a bridge between hard forks.

  - `lisk_snapshot.sh`

    Generates verified blockchain snapshots against a running instance of Lisk.

  - `lisk.sh`

    Manages the Lisk application process and attached postgres database.

  - `shared.sh`

    Defines various `bash` functions used by other scripts.

  - `tune.sh`

    Optimizes the `postgres` configuration according to the memory of the host machine.

## Authors

- https://github.com/karmacoma
- https://github.com/Isabello
- https://github.com/Gr33nDrag0n69
- https://github.com/Nazgolze

## Contributors

https://github.com/LiskHQ/lisk-scripts/graphs/contributors

## License

Copyright © 2016-2017 Lisk Foundation

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the [GNU General Public License](https://github.com/LiskHQ/lisk/tree/master/LICENSE) along with this program.  If not, see <http://www.gnu.org/licenses/>.
