process DSPSR {
    label 'cluster'

    publishDir = [
        path: { "${pubdir}/dspsr" },
        mode: 'link'
    ]

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
        arfiles=()
        for hdrfile in *.hdr; do
            dspsr \\
                -U 8192 \\
                -E ${parfile} \\
                -b ${nbin} \\
                -F ${nfine}:D -K \\
                -L ${tint} -A \\
                -O "\${hdrfile%.hdr}" \\
                "\$hdrfile"
            arfiles+=("\${hdrfile%.hdr}.ar")
        done
        psradd -R -o "${label}" \${arfiles[@]}
        rm \${arfiles[@]}
        """
    else
        """
        dspsr \\
            -cont \\
            -scloffs \\
            -U 8192 \\
            -E ${parfile} \\
            -b ${nbin} \\
            -F ${nfine*ncoarse}:D -K \\
            -L ${tint} -A \\
            -O "${label}" \\
            *.fits
        """
}