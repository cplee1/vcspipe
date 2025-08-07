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
include { ANALYSIS   } from './analysis'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow REDUCE {

    if (params.skip_bf) {
        if (params.dspsr || params.prepfold) {
            STAGE_DATA()
            ch_beamformed_data = STAGE_DATA.out.data
        }
    } else {
        BEAMFORM()

        if (params.dspsr || params.prepfold) {
            UNTAR(BEAMFORM.out.tarballs)
            ch_beamformed_data = UNTAR.out.data
        }
    }

    if (params.dspsr || params.prepfold) {
        // Post-process beamformed data

        ch_beamformed_data
            // input: ['name', 'obsid', 'begin-end', Path(data)], ...
            .map { [ it[0], it[1], it[2].split("-"), it[3] ] }
            // => ['name', 'obsid', ['begin', 'end'], Path(data)], ...
            .map { [ it[0], it[1], "${it[2][0].padLeft(4, '0')}_${it[2][1].padLeft(4, '0')}", it[3] ] }
            // => ['nameA', 'obsid', 'begin_end', Path(data)], ...
            .set { ch_beamformed_data_zp }

        GET_EPHEMERIS(ch_beamformed_data_zp)

        GET_EPHEMERIS.out.ephemeris
            // input: ['name', 'obsid', 'begin_end', Path(data), Path('/path/to/name.eph')], ...
            .map { name, obsid, interval, data, ephem -> [ name, obsid, "${name}_${obsid}_${interval}", data, ephem ] }
            // => ['name', 'obsid', 'label', Path(data), Path('/path/to/name.eph')], ...
            .map { _name, obsid, label, data, ephem -> [ label, obsid, data, ephem, file("${params.vcs_dir}/${obsid}/pointings_${params.timestamp}/${label}", type: 'dir') ] }
            // => ['label', 'obsid', Path(data), Path('/path/to/name.eph'), Path('/path/to/pubdir')], ...
            .set { ch_all_input }

        ch_all_input
            // input: ['label', 'obsid', Path(data), Path('/path/to/name.eph'), Path('/path/to/pubdir')], ...
            .map { [ it[0], it[2], it[3], it[4] ] }
            // => ['label', Path(data), Path('/path/to/name.eph'), Path('/path/to/pubdir')], ...
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
                // input: Path('/path/to/label.ar'), ...
                .map { [ it.baseName, it ] }
                // => ['label', Path('/path/to/label.ar')]
                .cross(ch_fold_input)
                // => [['label', Path('/path/to/label.ar')], ['label', Path(data), Path('/path/to/name.eph'), Path('/path/to/pubdir')]], ...
                .map { [ it[0][0], it[0][1], it[1][3] ] }
                // => ['label', Path('/path/to/label.ar'), Path('/path/to/pubdir')], ...
                .set { ch_archives }

            CLFD (ch_archives)

            CLFD.out.clfd_archive
                // input: Path('/path/to/name.ar.clfd'), ...
                .map { [ it.simpleName, it ] }
                // => ['label', Path('/path/to/label.ar.clfd')], ...
                .cross(ch_fold_input)
                // => [['label', Path('/path/to/label.ar.clfd')], ['label', Path(data), Path('/path/to/name.eph'), Path('/path/to/pubdir')]], ...
                .map { [ it[0][0], it[0][1], it[1][3] ] }
                // => ['label', Path('/path/to/label.ar.clfd'), Path('/path/to/pubdir')], ...
                .set { ch_clfd_archives }

            PAV (ch_clfd_archives)

            if (params.pdmp) {
                PDMP (
                    ch_clfd_archives,
                    Integer.valueOf(params.max_chans),
                    Integer.valueOf(params.max_subints),
                )

                ch_all_input
                    // input: ['label', 'obsid', Path(data), Path('/path/to/name.eph'), Path('/path/to/pubdir')], ...
                    .map { [ it[0], it[4] ]}
                    // => ['label', Path('/path/to/pubdir')], ...
                    .set { ch_label_pubdir }

                PDMP.out.archive
                    // input: Path('/path/to/label.ar.clfd.pdmp'), ...
                    .map { [ it.simpleName, it ] }
                    // => ['label', Path('/path/to/label.ar.clfd.pdmp')], ...
                    .cross(ch_label_pubdir)
                    // => [['label', Path('/path/to/label.ar.clfd.pdmp')], ['label', Path('/path/to/pubdir')]], ...
                    .map { [ it[0][0], it[0][1], it[1][1] ] }
                    // => ['label', Path('/path/to/label.ar.clfd.pdmp'), Path('/path/to/pubdir')], ...
                    .set { ch_pdmp_archives }

                ch_pdmp_archives
                    // input: ['label', Path('/path/to/label.ar.clfd.pdmp'), Path('/path/to/pubdir')], ...
                    .map { [ "${it[0]}_pdmp", it[1], it[2] ] }
                    // => ['label_pdmp', Path('/path/to/label.ar.clfd.pdmp'), Path('/path/to/pubdir')], ...
                    .set { ch_pdmp_archives_relabel }

                PAV_PDMP (ch_pdmp_archives_relabel)

                if (params.fluxcal || params.rmsynth) {
                    ch_all_input
                        // input: ['label', 'obsid', Path(data), Path('/path/to/name.eph'), Path('/path/to/pubdir')], ...
                        .map { [ it[0], it[1] ]}
                        // => ['label', 'obsid'], ...
                        .set { ch_label_obsid }

                    ch_pdmp_archives
                        // input: ['label', Path('/path/to/label.ar.clfd.pdmp'), Path('/path/to/pubdir')], ...
                        .cross(ch_label_obsid)
                        // => [['label', Path('/path/to/label.ar.clfd.pdmp'), Path('/path/to/pubdir')], ['label', 'obsid']], ...
                        .map { [ it[0][0], it[1][1], it[0][1], it[0][2] ] }
                        // => ['label', 'obsid', Path('/path/to/label.ar.clfd.pdmp'), Path('/path/to/pubdir')], ...
                        .set { ch_analysis_input }

                    ANALYSIS(ch_analysis_input)
                }
            } else {
                if (params.fluxcal || params.rmsynth) {
                    ch_all_input
                        // input: ['label', 'obsid', Path(data), Path('/path/to/name.eph'), Path('/path/to/pubdir')], ...
                        .map { [ it[0], it[1] ] }
                        // => ['label', 'obsid'], ...
                        .set { ch_label_obsid }

                    ch_clfd_archives
                        // input: ['label', Path('/path/to/label.ar.clfd'), Path('/path/to/pubdir')], ...
                        .cross(ch_label_obsid)
                        // => [['label', Path('/path/to/label.ar.clfd'), Path('/path/to/pubdir')], ['label', 'obsid']], ...
                        .map { [ it[0][0], it[1][1], it[0][1], it[0][2] ] }
                        // => ['label', 'obsid', Path('/path/to/label.ar.clfd'), Path('/path/to/pubdir')], ...
                        .set { ch_analysis_input }

                    ANALYSIS(ch_clfd_archives)
                }
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
