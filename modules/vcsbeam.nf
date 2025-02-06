process VCSBEAM {
    label 'cluster'

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
    tuple path(names_pointings), path('*.{hdr,vdif,fits}'), emit: beamformed_data

    script:
    """
    make_mwa_tied_array_beam -V

    srun make_mwa_tied_array_beam \\
        -b +${offset} \\
        -T ${duration} \\
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
