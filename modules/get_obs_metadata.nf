process GET_OBS_METADATA {

    input:
    tuple val(name), path(data)

    output:
    tuple val(name), env('obsid'), env('interval'), emit: targets
    tuple val(name), path(data), emit: beamformed_data

    script:
    if (!params.vdif)
        """
        ndat=\$(dspsr -list -cont *.fits | grep 'Number of time samples' | awk '{print \$6}')
        [[ ! -z '\$ndat' ]] || exit 2
        [[ ! '\$ndat' =~ [^0-9] ]] || exit 3
        echo "Number of time samples: \$ndat"

        obsid=\$(dspsr -list -cont *.fits | grep 'Source name' | awk '{print \$4}')
        [[ ! -z '\$obsid' ]] || exit 2
        [[ ! '\$obsid' =~ [^0-9] ]] || exit 3
        echo "Obs ID: \$obsid"

        t0_mjd=\$(dspsr -list -cont *.fits | grep 'Start time' | awk '{print \$4}')
        [[ ! -z '\$t0_mjd' ]] || exit 2
        [[ '\$t0_mjd' =~ ^[+-]?[0-9]+\.?[0-9]*$ ]] || exit 3
        echo "Start MJD: \$t0_mjd"
        
        # Integration time in seconds assuming 0.1 ms time resolution
        # Rounds down to the nearest second
        tint=\$((ndat/10000))
        echo "Integration time (s): \$tint"

        # Convert start time from MJD to GPS
        mjd_to_gps.py '\$t0_mjd' > /dev/null
        t0_gps=\$(mjd_to_gps.py '\$t0_mjd')

        # Calculate offsets from obs ID
        start_offset=\$((t0_gps - obsid))
        end_offset=\$((start_offset + tint))

        # Format interval string
        interval="\${start_offset}-\${end_offset}"
        """
    else
        """
        obsid=TODO
        interval=TODO
        """
}