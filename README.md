**Table fo Contents**

<div id="user-content-toc">

* [rmeadi.showsettings.sh](#rmeadishowsettingssh)
    * [Intro](#intro)
    * [Usage](#usage)
    * [Examples](#esamples)

</div>

# rmeadi.showsettings.sh

## Intro

**NOTE:** Before using please set appropriate Device ID at the beginning of this
script, based on the device model you have.

The script is using `amidi` command to send request to retrieve settings from
ADI-2 unit, parses the response and prints the settings.

It may not be too optimal for interactive use because it is quite slow. It takes
about 1.5 to 2 seconds. Using `--filter` option helps only a bit, e.g., parsing
and printing only Volume still takes about 1 second.

The protocol is described in https://www.rme-audio.de/downloads/adi2remote_midi_protocol.zip

## Usage

```
]$ rmeadi.showsettings.sh -h
Usage:
  rmeadi.showsettings.sh [optional arguments]

  Optional:
    --filter=FILTER         - Print only specified settings (see below).
    -h | --help             - this help message

The script retrieves settings from ADI-2 device using MIDI protocol and prints
them in more or less user friendly way.

Please set appropriate Device ID at the beginning of this script, based on the
device model you have.

FILTER is comma-separated list of address:index with :index part optional. For
valid values of address and index see:

  https://www.rme-audio.de/downloads/adi2remote_midi_protocol.zip

Examples:

  List only Line Out setttings (address=3):
    rmeadi.showsettings.sh --filter=3

  List Volume setting (index=12) for all outputs (addresses 3, 6 and 9):
    rmeadi.showsettings.sh --filter=3:12,6:12,9:12
```

## Examples

Print all settings:
```
]$ rmeadi.showsettings.sh

1075 bytes read
Input Settings: Ref Level: 1
Input Settings: Auto Ref Level: 0

...

Phones 34 EQ L: EQ Preset Select: 0
Line Out EQ L: EQ Preset Select: 3
Setup: 1:        Setup 1
Setup: 2:        Setup 2
Setup: 3:        Setup 3
Setup: 4:        Setup 4
Setup: 5:        Setup 5
Setup: 6:        Setup 6
Setup: 7:        Setup 7
Setup: 8:        Setup 8
Setup: 9:        Setup 9
DONE
```

List only Line Out setttings (address=3):
```
]$ rmeadi.showsettings.sh --filter=3

2484 bytes read
WARNING: SysEx stream desynchronized, got 0xf0 in state: read_sysx_header. Re-synchronizing.
Line Out Settings: Source: 0
Line Out Settings: Ref Level: 0
Line Out Settings: Auto Ref Level: 0
Line Out Settings: Mono: 0
Line Out Settings: Width: 1.00
Line Out Settings: M/S-Proc: 0
Line Out Settings: Polarity: 0
Line Out Settings: Crossfeed: 0
Line Out Settings: DA Filter: 2
Line Out Settings: De-Emphasis: 0
Line Out Settings: Dual EQ: 0
Line Out Settings: Volume: -39.5
Line Out Settings: Lock Volume: 0
Line Out Settings: Balance: 0
Line Out Settings: Mute: 0
Line Out Settings: Dim: 0
Line Out Settings: Loopback to USB: 0
Line Out Settings: Dig. DC Protection: 2
Line Out Settings: Loudness Enable: 0
Line Out Settings: Loudness Bass Gain: 7.0
Line Out Settings: Loudness Treble Gain: 7.0
Line Out Settings: Loudness Low Vol Ref: -30.0
Setup: 1:        Setup 1
Setup: 2:        Setup 2
Setup: 3:        Setup 3
Setup: 4:        Setup 4
Setup: 5:        Setup 5
Setup: 6:        Setup 6
Setup: 7:        Setup 7
Setup: 8:        Setup 8
Setup: 9:        Setup 9
DONE
```

List Volume setting (index=12) for all outputs (addresses 3, 6 and 9):
```
]$ rmeadi.showsettings.sh --filter=3:12,6:12,9:12

1769 bytes read
WARNING: SysEx stream desynchronized, got 0xf0 in state: read_sysx_header. Re-synchronizing.
Line Out Settings: Volume: -39.5
Phones 12 Settings: Volume: -96.5
Phones 34 Settings: Volume: -18.0
Setup: 1:        Setup 1
Setup: 2:        Setup 2
Setup: 3:        Setup 3
Setup: 4:        Setup 4
Setup: 5:        Setup 5
Setup: 6:        Setup 6
Setup: 7:        Setup 7
Setup: 8:        Setup 8
Setup: 9:        Setup 9
DONE
```
