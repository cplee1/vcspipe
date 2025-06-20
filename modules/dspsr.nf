process DSPSR {
    label 'cluster'

    publishDir "${pubdir}", mode: 'link'

    input:
    tuple val(name), val(label), path(parfile), path(data), val(pubdir)
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
        nbin=\$(get_optimal_nbin ${parfile} ${nbin} ${nfine} 1)
        rv=\$?
        [[ rv -ne 0 ]] && exit \$rv

        arfiles=()
        for hdrfile in *.hdr; do
            dspsr \\
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
        pam -D -m "${label}.ar"
        """
    else
        """
        nbin=\$(get_optimal_nbin ${parfile} ${nbin} ${nfine} ${ncoarse})
        rv=\$?
        [[ rv -ne 0 ]] && exit \$rv

        dspsr \\
            -cont \\
            -scloffs \\
            -U 8192 \\
            -E ${parfile} \\
            -b \$nbin \\
            -F ${nfine*ncoarse}:D -K \\
            -L ${tint} -A \\
            -O "${label}" \\
            *.fits
        """
}
