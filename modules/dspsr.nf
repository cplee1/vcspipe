process DSPSR {
    label 'cluster'

    publishDir = [
        path: { "${pubdir}/dspsr" },
        mode: 'link'
    ]

    input:
    tuple val(name), path(parfile), path(data), val(pubdir)
    val(nbin)
    val(nfine)
    val(ncoarse)
    val(tint)
    val(is_vdif)

    output:
    path("${name}.ar"), emit: archive

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
        psradd -R -o "${name}.ar" \${arfiles[@]}
        rm \${arfiles[@]}
        pam -D -m "${name}.ar"
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
            -O "${name}" \\
            *.fits
        """
}
