process FLUXCAL {
    label 'cluster'

    errorStrategy 'ignore'

    publishDir "${pubdir}/fluxcal", mode: 'link'

    input:
    tuple val(label), val(obsid), path(archive), val(pubdir)

    output:
    tuple val(label), path('*results.toml'), emit: results
    path('*.png'), emit: plots

    script:
    """
    wget 'http://ws.mwatelescope.org/metadata/fits?obs_id=${obsid}' -O '${obsid}.metafits'

    srun -N 1 -n 1 -c \$SLURM_CPUS_PER_TASK -m block:block:block \\
        singularity exec -B "\$PWD,\$(dirname \$MWA_BEAM_FILE)" ${params.tools_cont} pu-fluxcal \\
            -m '${obsid}.metafits' \\
            -a '${archive}' \\
            --fine_res '${params.fluxcal_fres}' \\
            --coarse_res '${params.fluxcal_cres}' \\
            --max_pix_per_job '${params.fluxcal_pixperjob}' \\
            --nfreq '${params.fluxcal_nfreq}' \\
            --ntime '${params.fluxcal_ntime}' \\
            --bw_flagged '${params.fluxcal_bw_flagged}' \\
            --plot_pb \\
            --plot_3d \\
            -o '${label}'

    singularity exec -B "\$PWD,\$(dirname \$MWA_BEAM_FILE)" ${params.tools_cont} pu-prof \\
        --meas_widths \\
        --plot_diagnostics \\
        -o '${label}' \\
        '${archive}'
    """
}
