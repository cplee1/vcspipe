process CALIBRATE_ARCHIVE {
    label 'cluster'

    publishDir "${pubdir}", mode: 'link'

    input:
    tuple val(label), path(archive), path(fluxcal_toml), path(rm_toml), val(pubdir)

    output:
    path('*.cal'), emit: archive

    script:
    """
    ln -s ${archive} ${archive}.ext

    parse_toml.py -u -t ${fluxcal_toml} -k Flux_scale > /dev/null
    flux_scale=\$(parse_toml.py -u -t ${fluxcal_toml} -k Flux_scale)

    parse_toml.py -t ${rm_toml} -k RM_prof > /dev/null
    rm_prof=\$(parse_toml.py -t ${rm_toml} -k RM_prof)

    echo "Faraday derotating to RM: \$rm_prof rad/m2"
    echo "Calibrating using flux scale: \$flux_scale mJy"
    srun -N 1 -n 1 -c 1 \\
        pam -R "\$rm_prof" --mult "\$flux_scale" -e cal -u . ${archive}.ext
    """
}
