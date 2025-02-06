process PARSE_TARGETS {
    label 'python'

    input:
    tuple val(interval), val(targets)

    output:
    path('names_pointings.csv'), emit: names_pointings

    script:
    """
    parse_targets.py \\
        -l "${interval}" \\
        -t "${targets instanceof Collection ? targets.join('" "') : targets}"
    """
}