process UNTAR {
    label 'cluster'

    input:
    tuple val(name), path(tarball)

    output:
    tuple val(name), path("${name}/*"), emit: data

    script:
    """
    tar xvmf ${tarball}
    """
}