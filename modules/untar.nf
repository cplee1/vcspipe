process UNTAR {
    label 'cluster'

    input:
    tuple val(name), path(tarball)

    output:
    tuple val(name), path("${name}*/*"), emit: data

    script:
    """
    srun -N 1 -n 1 -c 1 tar xvmf ${tarball}
    """
}