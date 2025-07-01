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
    threads_per_core=\$(lscpu | grep 'Thread(s) per core' | awk '{print \$4}')
    [[ ! -z "\$threads_per_core" ]] || exit 1
    [[ ! "\$threads_per_core" =~ [^0-9] ]] || exit 1

    clfd -o . -p \$((SLURM_CPUS_PER_TASK * threads_per_core)) ${archive}
    """
}
