process PARSE_TARGETS {
    label 'python'

    input:
    val(targets)

    output:
    path('names_pointings.csv'), emit: names_pointings

    script:
    """
    parse_targets.py -t "${targets instanceof Collection ? targets.join('" "') : targets}"
    """
}