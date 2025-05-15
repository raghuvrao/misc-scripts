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
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
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
        "-f",
        "--time-format",
        required=False,
        type=str,
        default="%F %a %T %z %Z",
        help="strftime format to display timestamp",
    )
    parser.add_argument(
        "-z",
        "--time-zones",
        required=False,
        type=str,
        default="Etc/UTC,America/Los_Angeles,America/New_York,Asia/Kolkata",
        help="timezones for which to display timestamps",
    )
    parser.add_argument(
        "-u",
        "--include-epoch-info",
        required=False,
        action="store_true",
        default=False,
        help="include UNIX-epoch information in the output",
    )
    parser.add_argument(
        "-n",
        "--include-now-info",
        required=False,
        action="store_true",
        default=False,
        help="include difference between input and now in the output",
    )
    args = parser.parse_args()

    ret = 0

    tz_utc = ZoneInfo("Etc/UTC")

    unix_ts = int(args.unix_timestamp or time.time())

    now = int(time.time())
    now_dt = datetime.fromtimestamp(now, tz_utc)

    if args.include_epoch_info:
        m = str(unix_ts)
        if args.include_now_info:
            delta_seconds = abs(now - unix_ts)
            days_hours_minutes_seconds = ""
            if delta_seconds >= 60:
                delta = timedelta(seconds=delta_seconds)
                hours = delta.seconds // 3600
                remaining_seconds = delta.seconds - (hours * 3600)
                minutes = remaining_seconds // 60
                seconds = remaining_seconds - (minutes * 60)
                days_hours_minutes_seconds = f" ({delta.days}d {hours}h {minutes}m {seconds}s)"
            m += f" [now: {now}] [diff: {delta_seconds} seconds{days_hours_minutes_seconds}]"
        m += " UNIX"
        print(m)

    tf = args.time_format
    try:
        my_dt = datetime.fromtimestamp(unix_ts, tz_utc)
    except ValueError as err:
        critical(f"translating {unix_ts}: {err}")

    for tz in uniq_order_preserve(args.time_zones):
        try:
            zone_info = ZoneInfo(tz)
            m = my_dt.astimezone(zone_info).strftime(tf)
        except ZoneInfoNotFoundError as err:
            warning(f"{tz}: {err}")
            ret = 3
            continue
        except OverflowError as err:
            error(f"{err} {str(zone_info)}")
            ret = 2
            continue
        if args.include_now_info:
            m += f" [now: {now_dt.astimezone(zone_info).strftime(tf)}]"
        m += " " + str(zone_info)
        print(m)

    return ret


if __name__ == "__main__":
    sys.exit(main())
