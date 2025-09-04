#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = [
#     "astropy",
# ]
# ///

import sys
from astropy.time import Time


def main() -> None:
    epoch_mjd = float(sys.argv[1])
    epoch = Time(epoch_mjd, format="mjd")
    print(round(epoch.gps))


if __name__ == "__main__":
    main()
