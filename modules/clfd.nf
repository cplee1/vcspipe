process CLFD {
    label 'cluster'

    publishDir "${pubdir}", mode: 'link'

    input:
    tuple val(label), path(archive), val(pubdir)

    output:
    path('*.clfd'), emit: clfd_archive
    path('*_clfd_report.h5'), emit: clfd_report

    script:
    """
    clfd -o . -p \$SLURM_CPUS_PER_TASK ${archive}
    """
}
