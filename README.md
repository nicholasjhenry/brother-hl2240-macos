# Brother HL-2240 on macOS

Brother stopped making Mac drivers for the HL-2240 after macOS 10.15, and the printer does not support AirPrint. This repository sets it up with [brlaser](https://github.com/Owl-Maintain/brlaser), an open-source CUPS driver for Brother laser printers. It was tested on macOS 26.6 (Apple silicon) with the printer shared by USB from an AirPort base station.

## Requirements

- Xcode Command Line Tools (`xcode-select --install`), for the compiler and CUPS headers.
- Homebrew, used to install `cmake` if it is missing.
- An administrator account, because the driver is installed with `sudo`.

## Install

Run this from a Terminal window, not from a tool that runs commands without a terminal, because `sudo` has to ask for your password:

```zsh
zsh install.sh
```

The script runs these steps:

1. Finds the printer with `lpinfo -v`. It finds both a direct USB connection and a network share.
2. Downloads brlaser 6.2.8 and checks the archive's SHA-256.
3. Builds the `rastertobrlaser` filter and generates the `br2240.ppd` printer description.
4. Installs both to `/Library/Printers/brlaser`, owned by root.
5. Adds the printer queue `Brother_HL_2240` and checks its PPD with `cupstestppd`.

If the printer is not found, pass its device URI as the first argument. The URI for the AirPort share is:

```zsh
zsh install.sh 'dnssd://Brother%20HL-2240%20series._riousbprint._tcp.local./'
```

Print a test page:

```zsh
echo test | lp -d Brother_HL_2240
```

## Why the filter is in /Library/Printers

System Integrity Protection makes `/usr/libexec/cups/filter` read-only, so brlaser's own `cmake --install` fails on macOS. The script writes the filter's absolute path into the PPD instead, which CUPS accepts for a filter owned by root.

## Remove

```zsh
sudo lpadmin -x Brother_HL_2240
sudo rm -rf /Library/Printers/brlaser
```

## Upgrade brlaser

Change `BRLASER_VERSION` in `install.sh`, download the new release archive, and set `BRLASER_SHA256` to the output of `shasum -a 256` on it.
