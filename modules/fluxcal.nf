process FLUXCAL {
    label 'cluster'

    publishDir "${pubdir}/fluxcal", mode: 'link'

    input:
    tuple val(label), val(obsid), val(archive), val(pubdir)

    output:
    path('inputs.toml'), emit: inputs
    path('results.toml'), emit: results
    path('*.png'), emit: plots

    script:
    """
    wget 'http://ws.mwatelescope.org/metadata/fits?obs_id=${obsid}' -O '${obsid}.metafits'

    singularity exec -B "\$PWD,\$(dirname \$MWA_BEAM_FILE)" ${params.tools_cont} fluxcal \\
        -m '${obsid}.metafits' \\
        -a '${archive}' \\
        --fine_res 2 \\
        --coarse_res 10 \\
        --nfreq 4 \\
        --ntime 4 \\
        --bw_flagged 0.125 \\
        --plot_profile \\
        --plot_pb \\
        --plot_3d
    """
}
