process GET_OBS_METADATA {

    input:
    tuple val(name), path(data)

    output:
    tuple val(name), env('obsid'), env('interval'), path(data), emit: beamformed_data

    script:
    if (params.vdif)
        """
        hdr_files=(*.hdr)

        ndat=\$(dspsr -list \${hdr_files[0]} | grep 'Number of time samples' | awk '{print \$6}')
        [[ ! -z "\$ndat" ]] || exit 2
        [[ ! "\$ndat" =~ [^0-9] ]] || exit 3
        echo "Number of time samples: \$ndat"

        obsid=\$(python -c "print('\${hdr_files[0]}'.split('_')[1])")
        [[ ! -z "\$obsid" ]] || exit 2
        [[ ! "\$obsid" =~ [^0-9] ]] || exit 3
        echo "Obs ID: \$obsid"

        t0_mjd=\$(dspsr -list \${hdr_files[0]} | grep 'Start time' | awk '{print \$4}')
        [[ ! -z "\$t0_mjd" ]] || exit 2
        [[ "\$t0_mjd" =~ ^[+-]?[0-9]+\\.?[0-9]*\$ ]] || exit 3
        echo "Start MJD: \$t0_mjd"

        # Integration time in seconds assuming 1.28 Msps
        # Rounds down to the nearest second
        tint=\$((ndat/1280000))
        echo "Integration time (s): \$tint"

        # Convert start time from MJD to GPS
        mjd_to_gps.py "\$t0_mjd" > /dev/null
        t0_gps=\$(mjd_to_gps.py "\$t0_mjd")

        # Calculate offsets from obs ID
        start_offset=\$((t0_gps - obsid))
        end_offset=\$((start_offset + tint))

        # Format interval string
        interval="\${start_offset}-\${end_offset}"
        """
    else
        """
        ndat=\$(dspsr -list -cont *.fits | grep 'Number of time samples' | awk '{print \$6}')
        [[ ! -z "\$ndat" ]] || exit 2
        [[ ! "\$ndat" =~ [^0-9] ]] || exit 3
        echo "Number of time samples: \$ndat"

        obsid=\$(dspsr -list -cont *.fits | grep 'Source name' | awk '{print \$4}')
        [[ ! -z "\$obsid" ]] || exit 2
        [[ ! "\$obsid" =~ [^0-9] ]] || exit 3
        echo "Obs ID: \$obsid"

        t0_mjd=\$(dspsr -list -cont *.fits | grep 'Start time' | awk '{print \$4}')
        [[ ! -z "\$t0_mjd" ]] || exit 2
        [[ "\$t0_mjd" =~ ^[+-]?[0-9]+\\.?[0-9]*\$ ]] || exit 3
        echo "Start MJD: \$t0_mjd"
        
        # Integration time in seconds assuming 10 ksps
        # Rounds down to the nearest second
        tint=\$((ndat/10000))
        echo "Integration time (s): \$tint"

        # Convert start time from MJD to GPS
        mjd_to_gps.py "\$t0_mjd" > /dev/null
        t0_gps=\$(mjd_to_gps.py "\$t0_mjd")

        # Calculate offsets from obs ID
        start_offset=\$((t0_gps - obsid))
        end_offset=\$((start_offset + tint))

        # Format interval string
        interval="\${start_offset}-\${end_offset}"
        """
}
