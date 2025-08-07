process UNTAR {
    label 'cluster'

    input:
    tuple val(name), val(obsid), val(interval), path(tarball)

    output:
    tuple val(name), val(obsid), val(interval), path("${name}*/*"), emit: data

    script:
    """
    srun -N 1 -n 1 -c 1 tar xvmf ${tarball}
    """
}