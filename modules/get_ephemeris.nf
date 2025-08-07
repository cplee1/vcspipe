process GET_EPHEMERIS {
    
    input:
    tuple val(name), val(obsid), val(interval), val(data)

    output:
    tuple val(name), val(obsid), val(interval), val(data), path("${name}.eph"), emit: ephemeris

    script:
    """
    ephem_dir="\${MYSOFTWARE}/resources/mtpa_par_files"
    ephem_file="\${ephem_dir}/${name}.par"

    if [[ -r "\$ephem_file" ]]; then
        cp "\$ephem_file" "${name}.eph"
        exit 0
    else
        echo "Could not find ephemeris in MPTA list."
    fi

    echo "Retreiving ephemeris from PSRCAT..."
    psrcat -v || true
    psrcat -e "${name}" > "${name}.eph"

    if [[ ! -z \$(grep WARNING "${name}.eph") ]]; then
        echo "Could not find pulsar in PSRCAT."
        exit 1
    fi
    """
}
