#!/usr/bin/env python3

# Author: Raghu Rao <raghu.v.rao@gmail.com>


import argparse
import sys
import time

from datetime import datetime, timedelta
from pytz import timezone, utc, UnknownTimeZoneError


def uniq_order_preserve(comma_separated_sequence):
    """Return unique items from a comma-separated sequence of items, while preserving order.

    Idea from https://www.peterbe.com/plog/uniqifiers-benchmark
    """
    seen = set()
    seen_add = seen.add
    for x in comma_separated_sequence.split(','):
        x = x.strip()
        if x in seen:
            continue
        seen_add(x)
        yield x


def main():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description=(
            'convert a unix timestamp to various timezones;'
            ' without any arguments, print current time in various timezones'
        ),
    )
    parser.add_argument(
        'unix_timestamp',
        nargs='?',
        type=float,
        default=None,
        help='UNIX timestamp to convert; floating-point is accepted, fractional part is truncated',
    )
    parser.add_argument(
        '-f',
        '--time-format',
        required=False,
        type=str,
        default='%F %a %T %Z(UTC%z)',
        help='strftime format to display timestamp',
    )
    parser.add_argument(
        '-z',
        '--time-zones',
        required=False,
        type=str,
        default='Etc/UTC,US/Pacific,US/Eastern,Asia/Kolkata',
        help='timezones for which to display timestamps',
    )
    parser.add_argument(
        '-u',
        '--include-epoch-info',
        required=False,
        action='store_true',
        default=False,
        help='include UNIX-epoch information in the output',
    )
    parser.add_argument(
        '-n',
        '--include-now-info',
        required=False,
        action='store_true',
        default=False,
        help='include difference between input and now in the output',
    )
    args = parser.parse_args()

    # Work out the output timezones.
    tzs = []
    unknown_tzs = []
    for tz in uniq_order_preserve(args.time_zones):
        try:
            tzs.append(timezone(tz.strip()))
        except UnknownTimeZoneError:
            unknown_tzs.append(tz)
    if any(unknown_tzs):
        print(f"[WARNING] Unknown timezones: {unknown_tzs}", file=sys.stderr)

    unix_ts = int(args.unix_timestamp or time.time())

    now = int(time.time())
    now_dt = datetime.utcfromtimestamp(now).replace(tzinfo=utc)

    if args.include_epoch_info:
        m = str(unix_ts)
        if args.include_now_info:
            delta_seconds = abs(now - unix_ts)
            days_hours_minutes_seconds = ''
            if delta_seconds >= 60:
                delta = timedelta(seconds=delta_seconds)
                hours = delta.seconds // 3600
                remaining_seconds = delta.seconds - (hours * 3600)
                minutes = remaining_seconds // 60
                seconds = remaining_seconds - (minutes * 60)
                days_hours_minutes_seconds = f" ({delta.days}d {hours}h {minutes}m {seconds}s)"
            m += f" [now: {now}] [diff: {delta_seconds} seconds{days_hours_minutes_seconds}]"
        m += ' UNIX'
        print(m, file=sys.stdout)

    tf = args.time_format
    my_dt = datetime.utcfromtimestamp(unix_ts).replace(tzinfo=utc)
    for tz in tzs:
        m = my_dt.astimezone(tz).strftime(tf)
        if args.include_now_info:
            m += f" [now: {now_dt.astimezone(tz).strftime(tf)}]"
        m += ' ' + str(tz)
        print(m, file=sys.stdout)


if __name__ == '__main__':
    main()
