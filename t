#!/usr/bin/env python3

# Author: Raghu Rao <raghu.v.rao@gmail.com>


import argparse
import sys
import time

from datetime import datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


def uniq_order_preserve(comma_separated_sequence):
    """Return unique items from a comma-separated sequence of items, while preserving order.

    Idea from https://www.peterbe.com/plog/uniqifiers-benchmark
    """
    seen = set()
    seen_add = seen.add
    for x in comma_separated_sequence.split(","):
        x = x.strip()
        if x not in seen:
            seen_add(x)
            yield x


def mesg(prefix, message, f=sys.stdout):
    pfx = f"{prefix}: " if prefix else ""
    print(f"{pfx}{message}", file=f)


def info(message):
    mesg("INFO", message)


def warning(message):
    mesg("WARNING", message, sys.stderr)


def error(message):
    mesg("ERROR", message, sys.stderr)


def critical(message):
    mesg("CRITICAL", message, sys.stderr)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description=(
            "convert a unix timestamp to various timezones;"
            " without any arguments, print current time in various timezones"
        ),
    )
    parser.add_argument(
        "unix_timestamp",
        nargs="?",
        type=float,
        default=None,
        help="UNIX timestamp to convert; floating-point is accepted, fractional part is truncated",
    )
    parser.add_argument(
        "-f", "--time-format",
        required=False,
        type=str,
        default="",
        help="strftime format to display timestamp (default: ISO 8601 format)",
    )
    parser.add_argument(
        "-z", "--time-zones",
        required=False,
        type=str,
        default="Etc/UTC,America/Los_Angeles,America/New_York,Asia/Kolkata",
        help="timezones for which to display timestamps (default: %(default)s)",
    )
    parser.add_argument(
        "-u", "--include-epoch-info",
        required=False,
        action="store_true",
        default=False,
        help="include UNIX-epoch information in the output",
    )
    parser.add_argument(
        "-n", "--include-now-info",
        required=False,
        action="store_true",
        default=False,
        help="include difference between input and now in the output",
    )
    args = parser.parse_args()

    ret = 0

    tz_utc = ZoneInfo("Etc/UTC")

    now_unix = int(time.time())
    unix_ts = int(args.unix_timestamp or now_unix)

    my_dt = None
    if args.unix_timestamp:
        unix_ts = int(args.unix_timestamp)
        try:
            my_dt = datetime.fromtimestamp(unix_ts, tz_utc)
        except ValueError as err:
            critical(f"translating {unix_ts}: {err}")
    else:
        my_dt = datetime.now(tz=tz_utc)

    now_dt = datetime.now(tz=tz_utc)

    if args.include_epoch_info:
        m = str(unix_ts)
        if args.include_now_info:
            delta = now_dt - my_dt
            minutes, seconds = divmod(delta.seconds, 60)
            hours, minutes = divmod(minutes, 60)
            delta_str = f'{"-" if delta.days < 0 else ""}P{abs(delta.days)}DT{hours:d}H{minutes:d}M{seconds:d}S'
            m += f" [now: {now_unix}] [diff: {delta_str}]"
        m += " UNIX"
        print(m)

    tf = args.time_format
    for tz in uniq_order_preserve(args.time_zones):
        try:
            zone_info = ZoneInfo(tz)
            my_dt_z = my_dt.astimezone(zone_info)
            if tf:
                m = my_dt_z.strftime(tf)
            else:
                m = f"{my_dt_z.strftime('%a')} {my_dt_z.isoformat()} ({my_dt_z.strftime('%Z')})"
        except ZoneInfoNotFoundError as err:
            warning(f"{tz}: {err}")
            ret = 3
            continue
        except OverflowError as err:
            error(f"{err} {str(zone_info)}")
            ret = 2
            continue
        if args.include_now_info:
            try:
                now_dt_z = now_dt.astimezone(zone_info)
                if tf:
                    n = now_dt_z.strftime(tf)
                else:
                    n = f"{now_dt_z.strftime('%a')} {now_dt_z.isoformat()} ({now_dt_z.strftime('%Z')})"
            except OverflowError as err:
                error(f"{err} {str(zone_info)}")
                ret = 2
                continue
            m += f" [now: {n}]"
        m += " " + str(zone_info)
        print(m)

    return ret


if __name__ == "__main__":
    sys.exit(main())
