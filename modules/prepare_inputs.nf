process PREPARE_INPUTS {

    input:
    tuple val(names), val(rajs), val(decjs)

    output:
    tuple path('names_pointings.txt'), path('pointings.txt'), emit: pointings

    script:
    """
    names=("${names instanceof Collection ? names.join('" "') : names}")
    rajs=("${rajs instanceof Collection ? rajs.join('" "') : rajs}")
    decjs=("${decjs instanceof Collection ? decjs.join('" "') : decjs}")

    for (( idx=0; idx<\${#names[@]}; idx++ )); do
        echo "\${names[idx]} \${rajs[idx]}_\${decjs[idx]}" >> names_pointings.txt
        echo "\${rajs[idx]} \${decjs[idx]}" >> pointings.txt
    done
    """
}