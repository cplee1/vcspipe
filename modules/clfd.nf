process CLFD {
    label 'cluster'

    publishDir = [
        path: { "${pubdir}/dspsr" },
        mode: 'link'
    ]

    input:
    tuple val(name), path(archive), val(pubdir)

    output:
    path('*.clfd'), emit: clfd_archive
    path('*_clfd_report.h5'), emit: clfd_report

    script:
    """
    clfd -o . -p \$SLURM_CPUS_PER_TASK ${archive}
    """
}