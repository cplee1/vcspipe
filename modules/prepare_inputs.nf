process PREPARE_INPUTS {

    input:
    tuple val(names), val(pointings)

    output:
    tuple path('names_pointings.txt'), path('pointings.txt'), emit: pointings

    script:
    """
    names=("${names instanceof Collection ? names.join('" "') : names}")
    pointings=("${pointings instanceof Collection ? pointings.join('" "') : pointings}")

    for (( idx=0; idx<\${#names[@]}; idx++ )); do
        echo "\${names[idx]} \${pointings[idx]}" >> names_pointings.txt
        echo "\${pointings[idx]}" >> pointings.txt
    done
    """
}