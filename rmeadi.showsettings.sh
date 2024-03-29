#!/usr/bin/env bash
set -euo pipefail

# Based on https://www.rme-audio.de/downloads/adi2remote_midi_protocol.zip

# This script retrieves settings from ADI-2 device using MIDI protocol and
# prints them in more or less user friendly way.

# Set appropriate Device ID below:

# 0x71 - ADI-2 DAC
# 0x72 - ADI-2 Pro
# 0x73 - ADI-2/4 Pro SE
device_id=0x72



die() {
    echo "${1}" >&2
    exit 1
}
die_usage() {
    echo "${1}" >&2
    usage >&2
    exit 1
}
die_parsing_midi() {
    echo "${1}" >&2

    declare -i offset=0
    while LANG=C read -r -n 60 line; do
        printf "%04d - %s\n" "${offset}" "${line}" >&2
        offset+=20
    done < <(tr -d '\n' <"${tmp_dir}/midi.hex")

    exit 1
}

bcdo() {
    echo "${1}" | bc -l
}

 device_index_mask=$(( (1 <<  6) - 1 ))
 device_value_mask=$(( (1 << 11) - 1 ))
channel_index_mask=$(( (1 <<  5) - 1 ))
channel_value_mask=$(( (1 << 12) - 1 ))

# The map {address -> index} is used to filter which elements to parse and print
declare -A filter_map=()

decode_parameter() {
    hexstring="${1}"

    val=$(printf "%d" "0x${hexstring}")
    byte_1=$(( (val >> 16) & 0xff ))
    byte_2=$(( (val >>  8) & 0xff ))
    byte_3=$(( (val >>  0) & 0xff ))

    address=$(( byte_1 >> 3 ))

    allowed_index=""
    if [ "${#filter_map[*]}" -gt 0 ]; then
        if [ -v "filter_map[${address}]" ]; then
            allowed_index="${filter_map[${address}]}"
        else
            return 0
        fi
    fi

    if [ "${address}" -eq 12 ]; then
        # Device parameters:
        # 0AAA AIII   0III VVVV   0VVV VVVV
        index=$(( (byte_1 << 3 | byte_2 >> 4) & device_index_mask ))
        value=$(( (byte_2 << 7 | byte_3     ) & device_value_mask ))
        print_device_parameter "${index}" "${value}"
    else
        # Channel parameters
        # 0AAA AIII   0IIV VVVV   0VVV VVVV
        index=$(( (byte_1 << 2 | byte_2 >> 5) & channel_index_mask ))

        if [ -n "${allowed_index}" ] && [ "${index}" != "${allowed_index}" ]; then
            return 0
        fi

        value=$(( (byte_2 << 7 | byte_3     ) & channel_value_mask ))
        # Our bit manipulation created unsigned "value" while it should be 12-bit
        # signed value with range [-2048:2047]. Here we fix that:
        if [ "${value}" -ge 2048 ]; then
            value="$(( value - 4096 ))"
        fi
        print_channel_parameter "${address}" "${index}" "${value}"
    fi
}

print_device_parameter() {
    index="${1}"
    value="${2}"
    case "${index}" in
         1) echo "Device: Mute Line vs.: ${value}" ;;
         2) echo "Device: Auto Standby: ${value}" ;;
         3) echo "Device: DSD Detection: ${value}" ;;
         4) echo "Device: DSD Filter: ${value}" ;;
         5) echo "Device: DSD Direct (Line): ${value}" ;;
         6) echo "Device: Basic Mode: ${value}" ;;
         7) echo "Device: Digital Out Source: ${value}" ;;

         8) echo "Device: Dual Phones: ${value}" ;;
         9) echo "Device: Bal. TRS Phones Mode: ${value}" ;;
        10) echo "Device: Toggle Phones/Line: ${value}" ;;
        11) echo "Device: Mute Line vs. PH12: ${value}" ;;
        12) echo "Device: Mute Line vs. PH34: ${value}" ;;

        15) echo "Device: Clock Source: ${value}" ;;
        16) echo "Device: Sample Rate: ${value}" ;;

        25) echo "Device: Remap Keys: ${value}" ;;
        26) echo "Device: VOL (1): ${value}" ;;
        27) echo "Device: I/O (2): ${value}" ;;
        28) echo "Device: EQ (3): ${value}" ;;
        29) echo "Device: SETUP (4): ${value}" ;;
        22) echo "Device: IR 5: ${value}" ;;
        23) echo "Device: IR 6: ${value}" ;;
        24) echo "Device: IR 7: ${value}" ;;

        40) echo "Device: SPDIF Input: ${value}" ;;
        41) echo "Device: SRC Mode: ${value}" ;;
        42) echo "Device: SRC Gain dig.: ${value}" ;;
        43) echo "Device: Optical Out Source: ${value}" ;;

        32) echo "Device: Display Mode: ${value}" ;;
        33) echo "Device: Meter Color: ${value}" ;;
        34) echo "Device: Hor. Meter: ${value}" ;;
        35) echo "Device: AutoDark Mode: ${value}" ;;
        36) echo "Device: Show Vol. Screen: ${value}" ;;
        37) echo "Device: Lock UI: ${value}" ;;
         *) echo "Device: UNKNOWN PARAMETER ${index}: ${value}" ;;
    esac
}

print_channel_parameter() {
    address="${1}"
    index="${2}"
    value="${3}"

    case "${address}" in
         0) scope="Input Settings" ;;
         1) scope="Input EQ L" ;;
         2) scope="Input EQ R" ;;
         3) scope="Line Out Settings" ;;
         4) scope="Line Out EQ L" ;;
         5) scope="Line Out EQ R" ;;
         6) scope="Phones 12 Settings" ;;
         7) scope="Phones 12 EQ L" ;;
         8) scope="Phones 12 EQ R" ;;
         9) scope="Phones 34 Settings" ;;
        10) scope="Phones 34 EQ L" ;;
        11) scope="Phones 34 EQ R" ;;
         *) scope="UNKNOWN SCOPE ${address}" ;;
    esac

    incr="1"
    case "${address}" in
        0)
            case "${index}" in
                3 | 4)
                    incr="0.5"
                ;;
            esac
            print_input_ch_parameter "${scope}" "${index}" "${value}" "${incr}"
        ;;
        3 | 6 | 9)
            case "${index}" in
                5 | 14)
                    incr="0.01"
                ;;
                12)
                    incr="0.1"
                ;;
                21 | 22 | 23)           # Documentation says that Loudness Low Vol Ref (23) is scaled like Volume (12) but it doesn't seem so from the data I receive
                    incr="0.5"
                ;;
            esac
            print_output_ch_parameter "${scope}" "${index}" "${value}" "${incr}"
        ;;
        1 | 2 | 4 | 5 | 7 | 8 | 10 | 11)
            case "${index}" in
                6 | 9 | 12 | 15 | 19 | 23 | 26)
                    incr="0.1"
                ;;
                4 | 7 | 10 | 13 | 17 | 21 | 24)
                    incr="0.5"
                ;;
            esac
            print_output_eq_parameter "${scope}" "${index}" "${value}" "${incr}"
        ;;
        *)
            echo "${scope}"
        ;;
    esac
}

print_input_ch_parameter() {
    scope="${1}"
    index="${2}"
    value="${3}"
    incr="${4}"

    value="$(bcdo "${value} * ${incr}")"

    case "${index}" in
         1) echo "${scope}: Ref Level: ${value}" ;;
         2) echo "${scope}: Auto Ref Level: ${value}" ;;
         3) echo "${scope}: Trim Gain Left: ${value}" ;;
         4) echo "${scope}: Trim Gain Right: ${value}" ;;
         5) echo "${scope}: Phase Invert: ${value}" ;;
         6) echo "${scope}: M/S-Proc: ${value}" ;;
         7) echo "${scope}: AD Filter: ${value}" ;;
         8) echo "${scope}: Dual EQ: ${value}" ;;
         9) echo "${scope}: AD Conversion: ${value}" ;;
        10) echo "${scope}: DC Filter: ${value}" ;;
        11) echo "${scope}: RIAA Mode: ${value}" ;;
        12) echo "${scope}: RIAA Mono Bass: ${value}" ;;
         *) echo "${scope}: UNKNOWN PARAMETER ${index}: ${value}" ;;
    esac
}

print_output_ch_parameter() {
    scope="${1}"
    index="${2}"
    value="${3}"
    incr="${4}"

    value="$(bcdo "${value} * ${incr}")"

    case "${index}" in
         1) echo "${scope}: Source: ${value}" ;;
         2) echo "${scope}: Ref Level: ${value}" ;;
         3) echo "${scope}: Auto Ref Level: ${value}" ;;
         4) echo "${scope}: Mono: ${value}" ;;
         5) echo "${scope}: Width: ${value}" ;;
         6) echo "${scope}: M/S-Proc: ${value}" ;;
         7) echo "${scope}: Polarity: ${value}" ;;
         8) echo "${scope}: Crossfeed: ${value}" ;;
         9) echo "${scope}: DA Filter: ${value}" ;;
        10) echo "${scope}: De-Emphasis: ${value}" ;;
        11) echo "${scope}: Dual EQ: ${value}" ;;
        12) echo "${scope}: Volume: ${value}" ;;
        13) echo "${scope}: Lock Volume: ${value}" ;;
        14) echo "${scope}: Balance: ${value}" ;;
        15) echo "${scope}: Mute: ${value}" ;;
        16) echo "${scope}: Dim: ${value}" ;;
        17) echo "${scope}: Loopback to USB: ${value}" ;;
        18) echo "${scope}: Dig. DC Protection: ${value}" ;;
        19) echo "${scope}: Rear TRS Source: ${value}" ;;
        20) echo "${scope}: Loudness Enable: ${value}" ;;
        21) echo "${scope}: Loudness Bass Gain: ${value}" ;;
        22) echo "${scope}: Loudness Treble Gain: ${value}" ;;
        23) echo "${scope}: Loudness Low Vol Ref: ${value}" ;;
         *) echo "${scope}: UNKNOWN PARAMETER ${index}: ${value}" ;;
    esac
}

print_output_eq_parameter() {
    scope="${1}"
    index="${2}"
    value="${3}"
    incr="${4}"

    # The "sign" bit becomes factor-10 for frequencies
    if [ "${value}" -ge 0 ]; then
        value_freq="${value}"
    else
        value_freq="$(( (value + 2048) * 10 ))"
    fi

    value="$(bcdo "${value} * ${incr}")"

    case "${index}" in
         2) echo "${scope}: EQ Enable: ${value}" ;;
         3) echo "${scope}: Band 1 Type: ${value}" ;;
         4) echo "${scope}: Band 1 Gain: ${value}" ;;
         5) echo "${scope}: Band 1 Freq: ${value_freq}" ;;
         6) echo "${scope}: Band 1 Q: ${value}" ;;
         7) echo "${scope}: Band 2 Gain: ${value}" ;;
         8) echo "${scope}: Band 2 Freq: ${value_freq}" ;;
         9) echo "${scope}: Band 2 Q: ${value}" ;;
        10) echo "${scope}: Band 3 Gain: ${value}" ;;
        11) echo "${scope}: Band 3 Freq: ${value_freq}" ;;
        12) echo "${scope}: Band 3 Q: ${value}" ;;
        13) echo "${scope}: Band 4 Gain: ${value}" ;;
        14) echo "${scope}: Band 4 Freq: ${value_freq}" ;;
        15) echo "${scope}: Band 4 Q: ${value}" ;;
        16) echo "${scope}: Band 5 Type: ${value}" ;;
        17) echo "${scope}: Band 5 Gain: ${value}" ;;
        18) echo "${scope}: Band 5 Freq: ${value_freq}" ;;
        19) echo "${scope}: Band 5 Q: ${value}" ;;

        20) echo "${scope}: B/T Enable: ${value}" ;;
        21) echo "${scope}: Bass Gain: ${value}" ;;
        22) echo "${scope}: Bass Freq: ${value_freq}" ;;
        23) echo "${scope}: Bass Q: ${value}" ;;
        24) echo "${scope}: Treble Gain: ${value}" ;;
        25) echo "${scope}: Treble Freq: ${value_freq}" ;;
        26) echo "${scope}: Treble Q: ${value}" ;;

        27) echo "${scope}: Load B/T w. Preset: ${value}" ;;
        28) echo "${scope}: EQ Preset Select: ${value}" ;;
         *) echo "${scope}: UNKNOWN PARAMETER ${index}: ${value}" ;;
    esac
}

decode_name() {
    name_index="${1}"
    name_buf="${2}"
    x_escape="$(echo "${name_buf}" | sed 's/../\\x&/g')"
    echo -e "Setup: ${name_index}: ${x_escape}"
}

usage() {
    cat << EOF
Usage:
  $(basename "${0}") [optional arguments]

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
    $(basename "${0}") --filter=3

  List Volume setting (index=12) for all outputs (addresses 3, 6 and 9):
    $(basename "${0}") --filter=3:12,6:12,9:12
EOF
}

parse_filter_arg() {
    filter_arg="${1}"
    if [ -z "${filter_arg}" ]; then
        die_usage "Missing filter"
    fi
    # comma-separated list of address:index with :index part is optional
    for one_filter in ${filter_arg//,/ }; do
        if ! [[ "${one_filter}" =~ ^[0-9]+(:[0-9]+)?$ ]]; then
            die_usage "Invalid filter: ${one_filter}"
        fi
        address="${one_filter%:*}"
        index=""
        if [[ "${one_filter}" =~ : ]]; then
            index="${one_filter#*:}"
        fi
        filter_map[${address}]="${index}"
    done
}

arg="${1-}"
if [ "${arg}" = "-h" ] || [ "${arg}" = "--help" ]; then
    usage
    exit 0
fi
if [[ "${arg}" =~ ^--filter$ ]] || [[ "${arg}" =~ ^--filter= ]]; then
    parse_filter_arg "${arg:9}"
elif [ -n "${arg}" ]; then
    die_usage "Unknown argument: ${arg}"
fi

declare -ra required_cmds=(amidi od bc sed tr)
for cmd in "${required_cmds[@]}"; do
    if ! which "${cmd}" >/dev/null 2>&1; then
        echo "Required tools: ${required_cmds[*]}"
        die "Required tool not found: ${cmd}"
    fi
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}";' EXIT

# Select first ADI MIDI port.
port="$(amidi -l | grep -m1 ADI | tr -s ' ' | cut -d' ' -f2 || true)"
if [ -z "${port}" ]; then
    echo "No ADI MIDI port found"
    exit 1
fi

midi_cmd="$(printf "F0 00 20 0D %02x 03 09 F7" "${device_id}")"
amidi -p "${port}" -S "${midi_cmd}" -r "${tmp_dir}/midi.out" -t 0.1
od -An -tx1 -w1 -v "${tmp_dir}/midi.out" > "${tmp_dir}/midi.hex"

state=initial_sync
declare -i offset=-1
while LANG=C read -r b; do
    offset+=1

    # Expected inputs:
    #
    #   * Parameters
    #       F0 00 20 0D XX 01 P1 P2 P3 P1 P2 P3 ... F7
    #     where:
    #       * XX is Device ID
    #       * P1 P2 P3 are 3 bytes of a single parameter, multiple parameters can be present
    #
    #   * Setup names
    #       F0 00 20 0D XX 05 YY ZZ ZZ ... ZZ 00 7F F7
    #     where:
    #       * XX is Device ID
    #       * YY is Setup Index
    #       * ZZ are ASCII characters for the Setup Name
    #
    #   * Status
    #       F0 00 20 0D XX 07 ... F7
    #     where:
    #       * XX is Device ID

    if [ "${b}" = "f0" ] && [ "${state}" != "initial" ] && [ "${state}" != "initial_sync" ]; then
        echo "WARNING: SysEx stream desynchronized, got 0xf0 in state: ${state}. Re-synchronizing."
        state="initial"
    fi

    case "${state}" in
        initial_sync)
            case "${b}" in
                f0)                         # in case we started already synchronized, do the same thing as "initial" state
                    state=read_sysx_header
                    sysx_header_cnt=0
                ;;
                f7)
                    state=initial
                ;;
            esac
        ;;
        initial)
            case "${b}" in
                f0)
                    state=read_sysx_header
                    sysx_header_cnt=0
                ;;
                *)
                    die_parsing_midi "state=${state}, b=${b}, offset=${offset}"
                ;;
            esac
        ;;
        read_sysx_header)
            sysx_header_cnt=$((sysx_header_cnt + 1))
            if [ "${sysx_header_cnt}" -eq 3 ]; then
                state=read_device_id
            fi
        ;;
        read_device_id)
            case "${b}" in
                71 | 72 | 73)
                    state=read_command_id
                ;;
                *)
                    die_parsing_midi "state=${state}, b=${b}, offset=${offset}"
                ;;
            esac
        ;;
        read_command_id)
            case "${b}" in
                01) # Send Parameter(s) to remote
                    state=read_parameter
                    parameter_buf=""
                ;;
                05) # Send EQ-Preset name or Device-Setup name to remote
                    state=read_name_index
                ;;
                07) # Status message to remote
                    state=ignore_sysx_message
                ;;
                *)
                    die_parsing_midi "state=${state}, b=${b}, offset=${offset}"
                ;;
            esac
        ;;
        ignore_sysx_message)
            case "${b}" in
                f7)
                    state=initial
                ;;
            esac
        ;;
        read_parameter)
            case "${b}" in
                f7)
                    if [ -z "${parameter_buf}" ]; then
                        state=initial
                    else
                        die_parsing_midi "state=${state}, b=${b}, offset=${offset}, parameter_buf=${parameter_buf}"
                    fi
                ;;
                *)
                    parameter_buf+="${b}"
                    if [ "${#parameter_buf}" -eq 6 ]; then
                        decode_parameter "${parameter_buf}"
                        parameter_buf=""
                    fi
                ;;
            esac
        ;;
        read_name_index)
            case "${b}" in
                21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29)
                    name_index="${b:1}"
                    state=read_name
                    name_buf=""
                ;;
                *)
                    die_parsing_midi "state=${state}, b=${b}, offset=${offset}"
                ;;
            esac
        ;;
        read_name)
            case "${b}" in
                00)
                    # There still are same remaining bytes in this sysx message, so ignore them
                    state=ignore_sysx_message
                    decode_name "${name_index}" "${name_buf}"
                ;;
                *)
                    name_buf+="${b}"
                ;;
            esac
        ;;
        *)
            die_parsing_midi "state=${state}, b=${b}, offset=${offset}"
        ;;
    esac

done < "${tmp_dir}/midi.hex"

echo DONE
