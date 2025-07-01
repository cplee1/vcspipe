process CALIBRATE_ARCHIVE {
    label 'cluster'

    publishDir "${pubdir}", mode: 'link'

    input:
    tuple val(label), path(archive, stageAs: '*.ext'), path(fluxcal_toml), val(rm_prof), val(pubdir)

    output:
    path('*.cal'), emit: archive

    script:
    """
    parse_toml.py -t ${fluxcal_toml} -k flux_scale > /dev/null
    flux_scale=\$(parse_toml.py -t ${fluxcal_toml} -k flux_scale)

    echo "Faraday derotating to RM: ${rm_prof} rad/m2"
    echo "Calibrating using flux scale: \$flux_scale mJy"
    pam -R ${rm_prof} --mult "\$flux_scale" -e cal -u . ${archive}
    """
}
