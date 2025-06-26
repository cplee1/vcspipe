process RMSYNTH {
    label 'cluster'

    publishDir "${pubdir}/rmsynth", mode: 'link'

    input:
    tuple val(label), val(archive), val(pubdir)

    output:
    path('inputs.toml'), emit: inputs
    path('*.png'), emit: plots

    script:
    """
    singularity exec -B "\$PWD" ${params.tools_cont} pu-rmsynth \\
        -f 96 \\
        -n 5000 \\
        --rmres 0.1 \\
        --rmlim 250 \\
        --meas_rm_prof \\
        --plot_pa
    """
}