process DSPSR {
    label 'cluster'

    // publishDir "${pubdir}", mode: 'link'

    errorStrategy 'ignore'

    input:
    tuple val(label), path(data), path(parfile), val(pubdir)
    val(nbin)
    val(nfine)
    val(ncoarse)
    val(tint)
    val(is_vdif)

    output:
    path("${label}.ar"), emit: archive

    script:
    if (is_vdif)
        """
        export OMP_NUM_THREADS='${params.dspsr_cpus}'
        export OMP_PLACES=cores
        export OMP_PROC_BIND=close

        nbin=\$(get_optimal_nbin ${parfile} ${nbin} ${nfine} 1)
        rv=\$?
        [[ rv -ne 0 ]] && exit \$rv

        arfiles=()
        for hdrfile in *.hdr; do
            srun -N 1 -n 1 -c \$OMP_NUM_THREADS -m block:block:block \\
                dspsr \\
                    -t \$OMP_NUM_THREADS \\
                    -U 1024 \\
                    -E ${parfile} \\
                    -b \$nbin \\
                    -F ${nfine}:D \\
                    -L ${tint} -A \\
                    -O "\${hdrfile%.hdr}" \\
                    "\$hdrfile"
            arfiles+=("\${hdrfile%.hdr}.ar")
        done
        srun -N 1 -n 1 -c 1 psradd -R -o "${label}.ar" \${arfiles[@]}
        rm \${arfiles[@]}

        # Dedisperse (apply channel delays)
        srun -N 1 -n 1 -c 1 pam -D -m "${label}.ar"

        # Reset the RM to zero
        srun -N 1 -n 1 -c 1 pam --RM 0 -m "${label}.ar"
        """
    else
        """
        export OMP_NUM_THREADS='${params.dspsr_cpus}'
        export OMP_PLACES=cores
        export OMP_PROC_BIND=close

        nbin=\$(get_optimal_nbin ${parfile} ${nbin} ${nfine} ${ncoarse})
        rv=\$?
        [[ rv -ne 0 ]] && exit \$rv

        srun -N 1 -n 1 -c \$OMP_NUM_THREADS -m block:block:block \\
            dspsr \\
                -t \$OMP_NUM_THREADS \\
                -U 1024 \\
                -E ${parfile} \\
                -b \$nbin \\
                -K \\
                -L ${tint} -A \\
                -O "${label}" \\
                -cont \\
                -scloffs \\
                *.fits

        # Reset the RM to zero
        srun -N 1 -n 1 -c 1 pam --RM 0 -m "${label}.ar"
        """
}
