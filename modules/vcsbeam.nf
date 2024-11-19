process VCSBEAM {
    label 'cluster'

    publishDir = [
        path: { "${params.vcs_dir}/${params.obsid}/pointings" },
        mode: 'link'
    ]

    input:
    tuple path(names_pointings), path(pointings)
    val(offset)
    val(duration)
    val(low_chan)
    val(data_dir)
    val(vcs_metafits)
    val(cal_metafits)
    val(cal_solution)
    val(output_flag)

    output:
    path('*.tar'), emit: beamformed_data
    eval("make_mwa_tied_array_beam -V | awk '{print \$3}'"), emit: version

    script:
    """
    make_mwa_tied_array_beam -V

    make_mwa_tied_array_beam \\
        -b +${offset} \\
        -T ${duration} \\
        -f ${low_chan} \\
        -d ${data_dir} \\
        -m ${vcs_metafits} \\
        -c ${cal_metafits} \\
        -C ${cal_solution} \\
        -P ${pointings} \\
        -R NONE -U 0,0 -O -X -s \\
        ${output_flag}

    while IFS=' ' read -r name pointing; do
        mkdir "\$name"
        mv *"\$pointing"* "\$name"
        tar cvf "\${name}${output_flag}.tar" "\$name"
        [[ -d "\$name" ]] && rm -r "\$name"
    done < ${names_pointings}
    """
}