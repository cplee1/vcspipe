#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = [
#     "numpy",
#     "tomli>=1.1.0; python_version<'3.11'",
# ]
# ///

import argparse
import sys

if sys.version_info >= (3, 11):
    import tomllib
else:
    import tomli as tomllib


def main() -> None:
    parser = argparse.ArgumentParser(
        usage="%(prog)s [options]",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description="Get a target RA/Dec and name.",
        add_help=False,
    )
    parser.add_argument(
        "-h",
        "--help",
        action="help",
        help="Show this help information and exit.",
    )
    parser.add_argument(
        "-t",
        "--toml",
        type=str,
        required=True,
        help="The TOML file to read.",
    )
    parser.add_argument(
        "-k",
        "--key",
        type=str,
        required=True,
        help="The dictionary key of the item to print.",
    )
    args = parser.parse_args()

    with open(args.toml, "rb") as f:
        qty_dict = tomllib.load(f)

    if args.key not in qty_dict.keys():
        print(f"key not in dict: {args.key}")
        exit(1)

    print(qty_dict[args.key][0])


if __name__ == "__main__":
    main()
