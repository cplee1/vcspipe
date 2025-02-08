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

    // Input should be a space-separated string of target@begin-end
    Channel
        // Split up targets
        .of(params.targets.split(' '))
        // Split up names from times
        .map { str -> str.split('@') }
        .set { ch_targets }

    ch_targets
        .map { tup -> [ tup[1], tup[0] ] }
        .groupTuple()
        .set { ch_intervals }

    PARSE_TARGETS(ch_intervals)

    PARSE_TARGETS.out.names_pointings
        .splitCsv(skip: 1)
        // [interval, name, ra, dec]
        .map { tup -> [tup[0], [tup[1], tup[2], tup[3]]] }
        // [interval, [name, ra, dec]]
        .groupTuple(size: Integer.valueOf(params.num_beams), remainder: true)
        // [interval, [[name, ra, dec], ...]
        .map { tup -> [tup[0], GroovyCollections.transpose(tup[1])] }
        // [interval, [[name, ...], [ra, ...], [dec, ...]]]
        .map { tup -> [tup[0], tup[1][0], tup[1][1], tup[1][2]] }
        // [interval, [name, ...], [ra, ...], [dec, ...]]
        .set { ch_interval_names_ra_dec }

    PREPARE_INPUTS(ch_interval_names_ra_dec)

    PREPARE_INPUTS.out.pointings
        // [interval, names_pointings.txt, pointings.txt]
        .map { tup -> [tup[0].split('-'), tup[1], tup[2]] }
        // [[begin, end], names_pointings.txt, pointings.txt]
        .map { tup -> [Integer.valueOf(tup[0][0]), Integer.valueOf(tup[0][1]), tup[1], tup[2]] }
        // [begin, end, names_pointings.txt, pointings.txt]
        .set { ch_pointings }
    
    VCSBEAM (
        ch_pointings,
        Integer.valueOf(params.low_chan),
        file("${params.vcs_dir}/${params.obsid}/combined", type: 'dir', checkIfExists: true),
        file("${params.vcs_dir}/${params.obsid}/${params.obsid}.metafits", checkIfExists: true),
        file("${params.vcs_dir}/${params.obsid}/cal/${params.calid}/${params.calid}.metafits", checkIfExists: true),
        file("${params.vcs_dir}/${params.obsid}/cal/${params.calid}/hyperdrive/hyperdrive_solutions.bin", checkIfExists: true),
        params.vdif
    )

    TAR (
        VCSBEAM.out.beamformed_data,
        Integer.valueOf(params.obsid),
        params.vdif,
        file("${params.vcs_dir}/${params.obsid}/pointings_${params.timestamp}", type: 'dir')
    )

    if (params.dspsr || params.prepfold) {
        // Post-process beamformed data
        TAR.out.tarballs
            .flatten()
            // map to ["name", Path("/path/to/name_obsid_begin_end.tar")]
            // assume that the name does not have any underscores
            .map { [ it.baseName.split('_')[0], it ] }
            .set { ch_beamformed_data }

        UNTAR(ch_beamformed_data)

        ch_interval_names_ra_dec
            .map { it[1] }
            .flatten()
            .set { ch_names }

        GET_EPHEMERIS(ch_names)

        GET_EPHEMERIS.out.ephemeris
            .cross(UNTAR.out.data)
            // map to ["name", Path("/path/to/name.eph"), Path(data)]
            .map { [ it[0][0], it[0][1], it[1][1] ] }
            .cross(ch_targets)
            // map to ["name", "begin_end", Path("/path/to/name.eph"), Path(data)]
            .map { [ it[0][0], it[1][1].replace('-', '_'), it[0][1], it[0][2] ] }
            // map to  ["name", Path("/path/to/name.eph"), Path(data), Path(pubdir)]
            .map { name, interval, ephem, data -> [ name, ephem, data, file("${params.vcs_dir}/${params.obsid}/pointings_${params.timestamp}/${name}_${params.obsid}_${interval}", type: 'dir') ] }
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
