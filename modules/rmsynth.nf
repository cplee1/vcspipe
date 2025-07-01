process RMSYNTH {
    label 'cluster'

    publishDir "${pubdir}/rmsynth", mode: 'link'

    input:
    tuple val(label), val(archive), val(pubdir)

    output:
    tuple val(label), path('*_rm_prof.csv'), path('*_rm_phi.csv'), emit: results
    path('*.png'), emit: plots

    script:
    """
    singularity exec -B "\$PWD" ${params.tools_cont} pu-rmsynth \\
        -c \\
        -f 384 \\
        -n 5000 \\
        --rmres 0.1 \\
        --rmlim 250 \\
        --meas_rm_prof \\
        --plot_pa \\
        ${archive}
    """
}
