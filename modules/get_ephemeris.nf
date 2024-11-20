process GET_EPHEMERIS {
    
    input:
    val(name)

    output:
    tuple val(name), path("${name}.eph"), emit: ephemeris

    script:
    """
    """
}