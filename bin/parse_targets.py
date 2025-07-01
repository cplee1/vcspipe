#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = [
#     "psrqpy",
# ]
# ///

import argparse
import csv
import logging
import psrqpy


def format_sexigesimal(coord: str, add_sign: bool = False) -> str:
    """Format a sexigesimal coordinate properly. Will assume zero for any
    missing units. E.g. '09:23' will be formatted as '09:23:00.00'.

    Parameters
    ----------
    coord : `str`
        The sexigesimal coordinate to format.
    add_sign : `bool`, optional
        Add a sign to the output, by default False.

    Returns
    -------
    formatted_coord : `str`
        The properly formatted coordinate.
    """
    # Determine the sign
    if coord.startswith(("-", "–")):
        sign = "-"
        coord = coord[1:]
    elif coord.startswith("+"):
        sign = "+"
        coord = coord[1:]
    else:
        sign = "+"
    # Split up the units
    parts = coord.split(":")
    # Fill in the missing units
    if len(parts) == 3:
        deg = int(parts[0])
        minute = int(parts[1])
        second = float(parts[2])
    elif len(parts) == 2:
        deg = int(parts[0])
        minute = int(float(parts[1]))
        second = 0.0
    elif len(parts) == 1:
        deg = int(float(parts[0]))
        minute = 0
        second = 0.0
    else:
        raise ValueError("Invalid coordinate format.")
    # Add the sign back if specified
    if add_sign:
        formatted_coord = f"{sign}{int(deg):02d}:{int(minute):02d}:{second:05.2f}"
    else:
        formatted_coord = f"{int(deg):02d}:{int(minute):02d}:{second:05.2f}"
    return formatted_coord


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
        "--targets",
        type=str,
        nargs="*",
        required=True,
        help="A pulsar B-name or J-name, or a pointing in the form 'RA_DEC'.",
    )
    parser.add_argument(
        "-o",
        "--outfile",
        type=str,
        default="names_pointings.csv",
        help="The name of the output CSV file.",
    )
    parser.add_argument(
        "-l",
        "--label",
        type=str,
        default="no_label",
        help="A label to give the pulsars in the output file.",
    )
    args = parser.parse_args()
    logger = logging.getLogger(__name__)

    for target in args.targets:
        if target.startswith(("J", "B")):
            query = psrqpy.QueryATNF()
            logger.info(f"Using ATNF catalogue version {query.get_version}")
            break

    entries = []
    for target in args.targets:
        if target.startswith(("J", "B")):
            if target.startswith("B"):
                try:
                    pid = list(query["PSRB"]).index(target)
                    psrj = query["PSRJ"][pid]
                except ValueError:
                    logger.warning(f"Pulsar not in catalogue: {target}")
                    continue
            else:
                psrj = target
            pulsar = query.get_pulsar(psrj)
            if pulsar is None:
                logger.warning(f"Pulsar not in catalogue: {target}")
                continue
            raj = pulsar["RAJ"][0]
            decj = pulsar["DECJ"][0]
        elif "_" in target:
            try:
                raj, decj = target.split("_")
            except ValueError:
                logger.warning(f"Invalid pointing format: {target}")
                continue
        else:
            logger.warning(f"Target string not parseable: {args.target}")
            continue
        try:
            raj = format_sexigesimal(raj)
            decj = format_sexigesimal(decj, add_sign=True)
        except ValueError:
            logger.warning(f"Cannot format coordinates for target: {target}")
            continue
        entry = [args.label, target, raj, decj]
        entries.append(entry)

    with open(args.outfile, "w") as csvfile:
        spamwriter = csv.writer(csvfile, delimiter=",")
        spamwriter.writerow(["label", "name", "raj", "decj"])
        for entry in entries:
            spamwriter.writerow(entry)


if __name__ == "__main__":
    main()
