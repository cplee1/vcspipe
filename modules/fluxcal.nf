process FLUXCAL {
    label 'cluster'

    publishDir "${pubdir}/fluxcal", mode: 'link'

    input:
    tuple val(label), val(obsid), val(archive), val(pubdir)

    output:
    tuple val(label), path('*results.toml'), emit: results
    path('*.png'), emit: plots

    script:
    """
    wget 'http://ws.mwatelescope.org/metadata/fits?obs_id=${obsid}' -O '${obsid}.metafits'

    srun -N 1 -n 1 -c \$SLURM_CPUS_PER_TASK -m block:block:block \\
        singularity exec -B "\$PWD,\$(dirname \$MWA_BEAM_FILE)" ${params.tools_cont} fluxcal \\
            -m '${obsid}.metafits' \\
            -a '${archive}' \\
            --fine_res 2 \\
            --coarse_res 10 \\
            --max_pix_per_job 1000000 \\
            --nfreq 4 \\
            --ntime 4 \\
            --bw_flagged 0.125 \\
            --plot_profile \\
            --plot_pb \\
            --plot_3d
    """
}
