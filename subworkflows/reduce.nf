/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UNTAR           } from '../modules/untar'
include { GET_EPHEMERIS   } from '../modules/get_ephemeris'
include { DSPSR           } from '../modules/dspsr'
include { CLFD            } from '../modules/clfd'
include { PDMP            } from '../modules/pdmp'
include { PAV             } from '../modules/pav'
include { PAV as PAV_PDMP } from '../modules/pav'
include { PREPFOLD        } from '../modules/prepfold'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { BEAMFORM   } from './beamform'
include { STAGE_DATA } from './stage_data'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow REDUCE {

    if (params.skip_bf) {
        STAGE_DATA()
        ch_targets = STAGE_DATA.out.targets

        if (params.dspsr || params.prepfold) {
            ch_beamformed_data = STAGE_DATA.out.data
        }
    } else {
        BEAMFORM()

        BEAMFORM.out.targets
            .map { [it[0], "${params.obsid}", it[1]] }
            .set { ch_targets }

        if (params.dspsr || params.prepfold) {
            BEAMFORM.out.tarballs
                // input: [Path('/path/to/name_obsid_begin_end.tar'), ...], ...
                .flatten()
                // => Path('/path/to/name_obsid_begin_end.tar'), ...
                // assume that the name does not have any underscores
                .map { [ it.baseName.split('_')[0], it ] }
                // => ['name', Path('/path/to/name_obsid_begin_end.tar')], ...
                .set { ch_beamformed_data_tarballs }

            UNTAR(ch_beamformed_data_tarballs)
            ch_beamformed_data = UNTAR.out.data
        }
    }

    if (params.dspsr || params.prepfold) {
        // Post-process beamformed data

        ch_targets
            // input: // => ['nameA', 'begin-end'], ['nameB', 'begin-end'], ...
            .map { it[0] }
            // => 'nameA', 'nameB', ...
            .set { ch_names }

        GET_EPHEMERIS(ch_names)

        GET_EPHEMERIS.out.ephemeris
            // input: ['name', Path('/path/to/name.eph')], ...
            .cross(ch_beamformed_data)
            // => [['name', Path('/path/to/name.eph')], ['name', Path(data)]], ...
            .map { [ it[0][0], it[0][1], it[1][1] ] }
            // => ['name', Path('/path/to/name.eph'), Path(data)], ...
            .cross(ch_targets)
            // => [['name', Path('/path/to/name.eph'), Path(data)], ['name', 'obsid', 'begin-end']], ...
            .map { [ it[0][0], it[1][1], it[1][2].replace('-', '_'), it[0][1], it[0][2] ] }
            // => ['name', 'begin_end', Path('/path/to/name.eph'), Path(data)], ...
            .map { name, obsid, interval, ephem, data -> [ name, obsid, "${name}_${obsid}_${interval}", ephem, data ] }
            // => ['name', 'obsid', 'label', Path('/path/to/name.eph'), Path(data)], ...
            .map { name, obsid, label, ephem, data -> [ name, label, ephem, data, file("${params.vcs_dir}/${obsid}/pointings_${params.timestamp}/${label}", type: 'dir') ] }
            // => ['name', 'label', Path('/path/to/name.eph'), Path(data), Path('/path/to/pubdir')], ...
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
                // input: Path('/path/to/name.ar'), ...
                .map { [ it.baseName, it ] }
                // => ['name', Path('/path/to/name.ar')]
                .cross(ch_fold_input)
                // => [['name', Path('/path/to/name.ar')], ['name', 'label', Path('/path/to/name.eph'), Path(data), Path('/path/to/pubdir')]], ...
                .map { [ it[0][0], it[0][1], it[1][4] ] }
                // => ['name', Path('/path/to/name.ar'), Path('/path/to/pubdir')], ...
                .set { ch_archives }

            CLFD (ch_archives)

            CLFD.out.clfd_archive
                // input: Path('/path/to/name.ar.clfd'), ...
                .map { [ it.simpleName, it ] }
                // => ['name', Path('/path/to/name.ar.clfd')], ...
                .cross(ch_fold_input)
                // => [['name', Path('/path/to/name.ar.clfd')], ['name', 'label', Path('/path/to/name.eph'), Path(data), Path('/path/to/pubdir')]], ...
                .map { [ it[1][1], it[0][1], it[1][4] ] }
                // => ['label', Path('/path/to/name.ar.clfd'), Path('/path/to/pubdir')]
                .set { ch_clfd_archives }

            PAV (ch_clfd_archives)

            if (params.pdmp) {
                PDMP (
                    ch_clfd_archives,
                    Integer.valueOf(params.max_chans),
                    Integer.valueOf(params.max_subints),
                )

                ch_fold_input
                    // input: ['name', 'label', Path('/path/to/name.eph'), Path(data), Path('/path/to/pubdir')], ...
                    .map { [ "${it[1]}_pdmp", it[4] ]}
                    // => ['label_pdmp', Path('/path/to/pubdir')], ...
                    .set { ch_pdmp_pubdir }

                PDMP.out.archive
                    // input: Path('/path/to/label_pdmp.ar'), ...
                    .map { [ it.baseName, it ] }
                    // => ['label_pdmp', Path('/path/to/label_pdmp.ar')], ...
                    .cross(ch_pdmp_pubdir)
                    // => [['label_pdmp', Path('/path/to/label_pdmp.ar')], ['label_pdmp', Path('/path/to/pubdir')]], ...
                    .map { [ it[0][0], it[0][1], it[1][1] ] }
                    // => ['label_pdmp', Path('/path/to/label_pdmp.ar'), Path('/path/to/pubdir')], ...
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
