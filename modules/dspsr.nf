process DSPSR {
    label 'cluster'

    publishDir "${pubdir}", mode: 'link'

    input:
    tuple val(label), path(parfile), path(data), val(pubdir)
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
        threads_per_core=\$(lscpu | grep 'Thread(s) per core' | awk '{print \$4}')
        [[ ! -z "\$threads_per_core" ]] || exit 1
        [[ ! "\$threads_per_core" =~ [^0-9] ]] || exit 1

        nbin=\$(get_optimal_nbin ${parfile} ${nbin} ${nfine} 1)
        rv=\$?
        [[ rv -ne 0 ]] && exit \$rv

        arfiles=()
        for hdrfile in *.hdr; do
            dspsr \\
                -t \$((SLURM_CPUS_PER_TASK * threads_per_core)) \\
                -U 8192 \\
                -E ${parfile} \\
                -b \$nbin \\
                -F ${nfine}:D \\
                -L ${tint} -A \\
                -O "\${hdrfile%.hdr}" \\
                "\$hdrfile"
            arfiles+=("\${hdrfile%.hdr}.ar")
        done
        psradd -R -o "${label}.ar" \${arfiles[@]}
        rm \${arfiles[@]}

        # Dedisperse (apply channel delays)
        pam -D -m "${label}.ar"

        # Reset the RM to zero
        pam --RM 0 -m "${label}.ar"
        """
    else
        """
        threads_per_core=\$(lscpu | grep 'Thread(s) per core' | awk '{print \$4}')
        [[ ! -z "\$threads_per_core" ]] || exit 1
        [[ ! "\$threads_per_core" =~ [^0-9] ]] || exit 1

        nbin=\$(get_optimal_nbin ${parfile} ${nbin} ${nfine} ${ncoarse})
        rv=\$?
        [[ rv -ne 0 ]] && exit \$rv

        dspsr \\
            -t \$((SLURM_CPUS_PER_TASK * threads_per_core)) \\
            -U 8192 \\
            -E ${parfile} \\
            -b \$nbin \\
            -F ${nfine*ncoarse}:D -K \\
            -L ${tint} -A \\
            -O "${label}" \\
            -cont \\
            -scloffs \\
            *.fits

        # Reset the RM to zero
        pam --RM 0 -m "${label}.ar"
        """
}
