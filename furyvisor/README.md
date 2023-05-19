# furyavisor Quick Start

`furyavisor` is a small process manager around Furyunderverse binaries that monitors the governance module via stdout to see if there's a chain upgrade proposal coming in. If it see a proposal that gets approved it can be run manually or automatically to download the new code, stop the node, run the migration script, replace the node binary, and start with the new genesis file.

## Installation

Run:

`make build`

## Command Line Arguments And Environment Variables

All arguments passed to the `furyavisor` program will be passed to the current daemon binary (as a subprocess).
It will return `/dev/stdout` and `/dev/stderr` of the subprocess as its own. Because of that, it cannot accept
any command line arguments, nor print anything to output (unless it terminates unexpectedly before executing a
binary).

`furyavisor` reads its configuration from environment variables:

- `DAEMON_HOME` is the location where upgrade binaries should be kept (e.g. `$HOME/.furyad`).
- `DAEMON_NAME` is the name of the binary itself (eg. `furyad`, etc).
- `DAEMON_ALLOW_DOWNLOAD_BINARIES` (_optional_) if set to `true` will enable auto-downloading of new binaries
  (for security reasons, this is intended for full nodes rather than validators).
- `DAEMON_RESTART_AFTER_UPGRADE` (_optional_) if set to `true` it will restart the sub-process with the same
  command line arguments and flags (but new binary) after a successful upgrade. By default, `furyavisor` dies
  afterwards and allows the supervisor to restart it if needed. Note that this will not auto-restart the child
  if there was an error.

## Data Folder Layout

`$DAEMON_HOME/furyavisor` is expected to belong completely to `furyavisor` and
subprocesses that are controlled by it. The folder content is organised as follows:

```bash
.
├── current -> genesis or upgrades/<name>
├── genesis
│   └── bin
│       └── $DAEMON_NAME
└── upgrades
    └── <name>
        └── bin
            └── $DAEMON_NAME
```

Each version of the Furyunderverse application is stored under either `genesis` or `upgrades/<name>`, which holds `bin/$DAEMON_NAME`
along with any other needed files such as auxiliary client programs or libraries. `current` is a symbolic link to the currently
active folder (so `current/bin/$DAEMON_NAME` is the currently active binary).

_Note: the `name` variable in `upgrades/<name>` holds the URI-encoded name of the upgrade as specified in the upgrade module plan._

Please note that `$DAEMON_HOME/furyavisor` just stores the _binaries_ and associated _program code_.
The `furyavisor` binary can be stored in any typical location (eg `/usr/local/bin`). The actual blockchain
program will store it's data under their default data directory (e.g. `$HOME/.furyad`) which is independent of
the `$DAEMON_HOME`. You can choose to set `$DAEMON_HOME` to the actual binary's home directory and then end up
with a configuation like the following, but this is left as a choice to the system admininstrator for best
directory layout:

```bash
.furyad
├── config
├── data
└── furyavisor
```

## Usage

The system administrator admin is responsible for:

- installing the `furyavisor` binary and configure the host's init system (e.g. `systemd`, `launchd`, etc) along with the environmental variables appropriately;
- installing the `genesis` folder manually;
- installing the `upgrades/<name>` folders manually.

`furyavisor` will set the `current` link to point to `genesis` at first start (when no `current` link exists) and handles
binaries switch overs at the correct points in time, so that the system administrator can prepare days in advance and relax at upgrade time.

Note that blockchain applications that wish to support upgrades may package up a genesis `furyavisor` tarball with this information,
just as they prepare the genesis binary tarball. In fact, they may offer a tarball will all upgrades up to current point for easy download
for those who wish to sync a fullnode from start.

The `DAEMON` specific code and operations (e.g. tendermint config, the application db, syncing blocks, etc) are performed as normal.
Application binaries' directives such as command-line flags and environment variables work normally.

## Example: furyad

The following instructions provide a demonstration of `furyavisor`'s integration with the `furyad` application
shipped along the Furyunderverse's source code.

First compile `furyad`:

```bash
cd /workspace
make build
```

Set the required environment variables:

```bash
export DAEMON_NAME=furyad         # binary name
export DAEMON_HOME=$HOME/.furyad  # daemon's home directory
```

Create the `furyavisor`’s genesis folders and deploy the binary:

```bash
mkdir -p $DAEMON_HOME/furyavisor/genesis/bin
cp ./build/furyad $DAEMON_HOME/furyavisor/genesis/bin
```

Create a new key and setup the `furyad` node:

```bash
./scripts/setup_furyad.sh 12345678
```

For the sake of this demonstration, we would amend `voting_params.voting_period` in `.furyad/config/genesis.json` to a reduced time ~1 minutes (60s) and eventually launch `furyavisor`:

```bash
sed -i 's/voting_period" *: *".*"/voting_period": "60s"/g' .furyad/config/genesis.json
```

Now furyavisor is a replacement for furyad

```bash
furyavisor start
```

For the sake of this demonstration, we will hardcode a modification in `furyad` to simulate a code change.
In `furyad/app.go`, find the line containing the upgrade Keeper initialisation, it should look like
`app.upgradekeeper = upgradekeeper.NewKeeper(skipUpgradeHeights, ...)`.
After that line, add the following snippet:

```go
app.upgradekeeper.SetUpgradeHandler("ai-oracle", func(ctx sdk.Context, plan upgradetypes.Plan) {
    // Add modification logic
})
```

then rebuild it with `make build`

Submit a software upgrade proposal:

```bash
# check furya.env for allowing auto download and upgrade form a URL
# DAEMON_ALLOW_DOWNLOAD_BINARIES=true
# DAEMON_RESTART_AFTER_UPGRADE=true

# using s3 to store build file
aws s3 mb s3://furya
aws s3 cp build/furyad s3://furya --acl public-read
echo '{"binaries":{"linux/amd64":"https://furya.s3.amazonaws.com/furyad?versionId=new_furyad_version"}}' > build/manifest.json
aws s3 cp build/manifest.json s3://furya --acl public-read

# then submit proposal
furyad tx gov submit-proposal software-upgrade "v0.41.0" --title "upgrade Furyunderverse network to v0.41.0, patches the Dragonberry advisory with custom CosmWasm - backward compatibility for v0.13.2" --description "Please visit https://github.com/furyunderverse/furya to view the CHANGELOG for this upgrade" --from $USER --upgrade-height 9415363 --upgrade-info "https://furya.s3.us-east-2.amazonaws.com/v0.41.0/manifest.json" --deposit 10000000furya --chain-id Furyunderverse-testnet -y

```

Submit a `Yes` vote for the upgrade proposal:

```bash
furyad tx gov vote 1 yes --from $USER --chain-id $CHAIN_ID -y
```

Query the proposal to ensure it was correctly broadcast and added to a block:

```bash
furyad query gov proposal 1
```

The upgrade will occur automatically at height 20.
