process GET_EPHEMERIS {
    
    input:
    val(name)

    output:
    tuple val(name), path("${name}.eph"), emit: ephemeris

    script:
    """
    parfile='/software/projects/mwavcs/cplee/resources/mtpa_par_files/${name}.par'
    if [[ -f "\$parfile" ]]; then
        cp "\$parfile" "${name}.eph"
    else
        exit 1
    fi
    """
}