process VCSBEAM {
    label 'cluster'

    input:
    tuple val(begin_offset), val(end_offset), path(names_pointings), path(pointings)
    val(low_chan)
    val(data_dir)
    val(vcs_metafits)
    val(cal_metafits)
    val(cal_solution)
    val(output_flag)

    output:
    tuple val(begin_offset), val(end_offset), path(names_pointings), path('*.{hdr,vdif,fits}'), emit: beamformed_data

    script:
    """
    make_mwa_tied_array_beam -V

    srun make_mwa_tied_array_beam \\
        -b +${begin_offset} \\
        -T \$((${end_offset} - ${begin_offset})) \\
        -f ${low_chan} \\
        -d ${data_dir} \\
        -m ${vcs_metafits} \\
        -c ${cal_metafits} \\
        -C ${cal_solution} \\
        -P ${pointings} \\
        -R NONE -U 0,0 -O -X -s \\
        ${output_flag ? '-v' : '-p'}
    """
}
