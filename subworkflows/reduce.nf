/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PARSE_TARGETS   } from '../modules/parse_targets'
include { PREPARE_INPUTS  } from '../modules/prepare_inputs'
include { VCSBEAM         } from '../modules/vcsbeam'
include { TAR             } from '../modules/tar'
include { UNTAR           } from '../modules/untar'
include { GET_EPHEMERIS   } from '../modules/get_ephemeris'
include { DSPSR           } from '../modules/dspsr'
include { PDMP            } from '../modules/pdmp'
include { PAV             } from '../modules/pav'
include { PAV as PAV_PDMP } from '../modules/pav'
include { PREPFOLD        } from '../modules/prepfold'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow REDUCE {

    Channel
        .of(params.targets.split(' '))
        .collect()
        .set { ch_targets }

    PARSE_TARGETS(ch_targets)

    PARSE_TARGETS.out.names_pointings
        .splitCsv(skip: 1)
        .collate(Integer.valueOf(params.num_beams), remainder = true)
        .map { GroovyCollections.transpose(it) }
        .set { ch_names_ra_dec }

    PREPARE_INPUTS(ch_names_ra_dec)
    
    VCSBEAM (
        PREPARE_INPUTS.out.pointings,
        Integer.valueOf(params.offset),
        Integer.valueOf(params.duration),
        Integer.valueOf(params.low_chan),
        file("${params.vcs_dir}/${params.obsid}/combined", type: 'dir', checkIfExists: true),
        file("${params.vcs_dir}/${params.obsid}/${params.obsid}.metafits", checkIfExists: true),
        file("${params.vcs_dir}/${params.obsid}/cal/${params.calid}/${params.calid}.metafits", checkIfExists: true),
        file("${params.vcs_dir}/${params.obsid}/cal/${params.calid}/hyperdrive/hyperdrive_solutions.bin", checkIfExists: true),
        params.vdif
    )

    TAR (
        VCSBEAM.out.beamformed_data,
        params.vdif,
        file("${params.vcs_dir}/${params.obsid}/pointings_${params.timestamp}", type: 'dir')
    )

    if (params.dspsr || params.prepfold) {
        // Post-process beamformed data
        TAR.out.tarballs
            .flatten()
            // map to ["name", Path("/path/to/name.tar")]
            .map { [it.baseName, it] }
            .set { ch_beamformed_data }

        UNTAR(ch_beamformed_data)

        ch_names_ra_dec
            .map { it[0] }
            .flatten()
            .set { ch_names }

        GET_EPHEMERIS(ch_names)

        GET_EPHEMERIS.out.ephemeris
            .cross(UNTAR.out.data)
            // map to ["name", Path("/path/to/name.eph"), Path(data)]
            .map { [ it[0][0], it[0][1], it[1][1] ] }
            // map to  ["name", Path("/path/to/name.eph"), Path(data), Path(pubdir)]
            .map { name, ephem, data -> [ name, ephem, data, file("${params.vcs_dir}/${params.obsid}/pointings_${params.timestamp}/${name}", type: 'dir') ] }
            .set { ch_fold_input }

        if (params.dspsr) {
            DSPSR (
                ch_fold_input,
                Integer.valueOf(params.nbin),
                Integer.valueOf(params.nfine),
                Integer.valueOf(params.num_chan),
                Integer.valueOf(params.tint),
                params.vdif
            )

            DSPSR.out.archive
                // map to ["name", Path("/path/to/name.ar")]
                .map { [it.baseName, it] }
                .cross(ch_fold_input)
                // map to  ["name", Path("/path/to/name.ar"), Path(pubdir)]
                .map { [ it[0][0], it[0][1], it[1][3] ] }
                .set { ch_archives }

            PAV (ch_archives)

            if (params.pdmp) {
                PDMP (
                    ch_archives,
                    Integer.valueOf(params.max_chans),
                    Integer.valueOf(params.max_subints),
                )

                ch_fold_input
                    // map to ["name_pdmp", Path(pubdir)]
                    .map { [ "${it[0]}_pdmp", it[3] ]}
                    .set { ch_pdmp_pubdir }

                PDMP.out.archive
                    // map to ["name_pdmp", Path("/path/to/name_pdmp.ar")]
                    .map { [it.baseName, it] }
                    .cross(ch_pdmp_pubdir)
                    // map to  ["name_pdmp", Path("/path/to/name_pdmp.ar"), Path(pubdir)]
                    .map { [ it[0][0], it[0][1], it[1][1] ] }
                    .set { ch_pdmp_archives }

                PAV_PDMP (ch_pdmp_archives)
            }
        }

        if (params.prepfold) {
            if (params.vdif) {
                System.err.println('ERROR: prepfold cannot process voltage data. Skipping prepfold.')
            } else {
                PREPFOLD (
                    ch_fold_input,
                    Integer.valueOf(params.nbin),
                    Integer.valueOf(params.nsub),
                    Integer.valueOf(params.npart)
                )
            }
        }
    }
}