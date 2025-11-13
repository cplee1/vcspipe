process RMSYNTH {
    label 'cluster'

    errorStrategy 'ignore'

    publishDir "${pubdir}/rmsynth", mode: 'link'

    input:
    tuple val(label), path(archive), val(pubdir)

    output:
    tuple val(label), path('*results.toml'), emit: results
    path('*.png'), emit: plots

    script:
    """
    export NUMBA_NUM_THREADS=\$SLURM_CPUS_PER_TASK

    if [ -f '${pubdir}'/*rm_discard.txt ]; then
        dopt='--discard'
        read -r dl dr < '${pubdir}'/*rm_discard.txt
    else
        dopt=''
        dl=''
        dr=''
    fi

    # To activate these options, create these files
    if [ -f '${pubdir}'/mask_zero_peak_fwhm ]; then
        zpopt='--mask_zero_peak_fwhm'
    elif [ -f '${pubdir}'/mask_zero_peak ]; then
        zpopt='--mask_zero_peak_hwhm'
    else
        zpopt=''
    fi

    srun -N 1 -n 1 -c \$NUMBA_NUM_THREADS -m block:block:block \\
        singularity exec -B "\$PWD" ${params.tools_cont} pu-rmsynth \\
            -c \\
            -f 384 \\
            -n 5000 \\
            --rmres 0.1 \\
            --rmlim 300 \\
            --meas_rm_prof \\
            --meas_widths \\
            --plot_diagnostics \\
            --plot_publn_prof \\
            --plot_pa \\
            \$dopt \$dl \$dr \\
            \$zpopt \\
            ${archive}
    """
}
