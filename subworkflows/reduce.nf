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
include { CLFD            } from '../modules/clfd'
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

    // The target names must either be pulsar J/B names or pointings in RA_DEC
    // format (can be decimal or sexigesimal). Each target must be provided
    // a begin and end time offset from the beginning of the observation in
    // seconds, delineated from the target name by an '@' symbol.
    // E.g. 'J0437-4715@3000-3600' or '04:37:15.90_-47:15:09.11@3000-3600'
    Channel
        // input: 'nameA@begin-end nameB@begin-end ...'
        .of(params.targets.split(' '))
        // => 'nameA@begin-end', 'nameB@begin-end', ...
        .map { str -> str.split('@') }
        // => ['nameA', 'begin-end'], ['nameB', 'begin-end'], ...
        .set { ch_targets }

    // The targets will be grouped by time interval to process as separate
    // beamforming jobs.
    ch_targets
        // input: ['nameA', 'begin-end'], ['nameB', 'begin-end'], ...
        .map { tup -> [ tup[1], tup[0] ] }
        // => ['begin-end', 'nameA'], ['begin-end', 'nameB'], ...
        .groupTuple()
        // => ['begin-end', ['nameA', 'nameB']], ...
        .set { ch_intervals }

    PARSE_TARGETS(ch_intervals)

    // The targets will be grouped into jobs of max size $params.num_beams.
    // Therefore, in VDIF mode $params.num_beams must be set to 1.
    PARSE_TARGETS.out.names_pointings
        // input: names_pointings.csv
        .splitCsv(skip: 1)
        // => ['begin-end', 'name', 'ra', 'dec'], ...
        .map { tup -> [tup[0], [tup[1], tup[2], tup[3]]] }
        // => ['begin-end', ['name', 'ra', 'dec']], ...
        .groupTuple(size: Integer.valueOf(params.num_beams), remainder: true)
        // => ['begin-end', [['name', 'ra', 'dec'], ...]], ...
        .map { tup -> [tup[0], GroovyCollections.transpose(tup[1])] }
        // => ['begin-end', [['name', ...], ['ra', ...], ['dec', ...]]], ...
        .map { tup -> [tup[0], tup[1][0], tup[1][1], tup[1][2]] }
        // => ['begin-end', ['name', ...], ['ra', ...], ['dec', ...]], ...
        .set { ch_interval_names_ra_dec }

    PREPARE_INPUTS(ch_interval_names_ra_dec)

    PREPARE_INPUTS.out.pointings
        // input: ['begin-end', names_pointings.txt, pointings.txt], ...
        .map { tup -> [tup[0].split('-'), tup[1], tup[2]] }
        // => [['begin', 'end'], names_pointings.txt, pointings.txt], ...
        .map { tup -> [Integer.valueOf(tup[0][0]), Integer.valueOf(tup[0][1]), tup[1], tup[2]] }
        // => [Integer(begin), Integer(end), names_pointings.txt, pointings.txt], ...
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

    // Combining the beamformed data into tarballs allows us to split up the
    // output for multiple targets, which lets us process them separately and
    // publish them in separate directories.
    TAR (
        VCSBEAM.out.beamformed_data,
        Integer.valueOf(params.obsid),
        params.vdif,
        file("${params.vcs_dir}/${params.obsid}/pointings_${params.timestamp}", type: 'dir')
    )

    if (params.dspsr || params.prepfold) {
        // Post-process beamformed data

        TAR.out.tarballs
            // input: [Path('/path/to/name_obsid_begin_end.tar'), ...], ...
            .flatten()
            // => Path('/path/to/name_obsid_begin_end.tar'), ...
            // assume that the name does not have any underscores
            .map { [ it.baseName.split('_')[0], it ] }
            // => ['name', Path('/path/to/name_obsid_begin_end.tar')], ...
            .set { ch_beamformed_data }

        UNTAR(ch_beamformed_data)

        ch_interval_names_ra_dec
            // input: ['begin-end', ['name', ...], ['ra', ...], ['dec', ...]], ...
            .map { it[1] }
            // => ['name', ...], ...
            .flatten()
            // => 'name', ...
            .set { ch_names }

        GET_EPHEMERIS(ch_names)

        GET_EPHEMERIS.out.ephemeris
            // input: ['name', Path('/path/to/name.eph')], ...
            .cross(UNTAR.out.data)
            // => [['name', Path('/path/to/name.eph')], ['name', Path(data)]], ...
            .map { [ it[0][0], it[0][1], it[1][1] ] }
            // => ['name', Path('/path/to/name.eph'), Path(data)], ...
            .cross(ch_targets)
            // => [['name', Path('/path/to/name.eph'), Path(data)], ['name', 'begin-end']], ...
            .map { [ it[0][0], it[1][1].replace('-', '_'), it[0][1], it[0][2] ] }
            // => ['name', 'begin_end', Path('/path/to/name.eph'), Path(data)], ...
            .map { name, interval, ephem, data -> [ name, ephem, data, file("${params.vcs_dir}/${params.obsid}/pointings_${params.timestamp}/${name}_${params.obsid}_${interval}", type: 'dir') ] }
            // => ['name', Path('/path/to/name.eph'), Path(data), Path('/path/to/pubdir')], ...
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
                // => [['name', Path('/path/to/name.ar')], ['name', Path('/path/to/name.eph'), Path(data), Path('/path/to/pubdir')]], ...
                .map { [ it[0][0], it[0][1], it[1][3] ] }
                // => ['name', Path('/path/to/name.ar'), Path('/path/to/pubdir')], ...
                .set { ch_archives }

            CLFD (ch_archives)

            CLFD.out.clfd_archive
                .view()

            CLFD.out.clfd_archive
                // input: Path('/path/to/name.ar.clfd'), ...
                .map { [ it.baseName, it ] }
                // => ['name', Path('/path/to/name.ar.clfd')], ...
                .cross(ch_fold_input)
                // => [['name', Path('/path/to/name.ar.clfd')], ['name', Path('/path/to/name.eph'), Path(data), Path('/path/to/pubdir')]], ...
                .map { [ it[0][0], it[0][1], it[1][3] ] }
                // => ['name', Path('/path/to/name.ar.clfd'), Path('/path/to/pubdir')]
                .set { ch_clfd_archives }

            ch_clfd_archives
                .view()

            PAV (ch_clfd_archives)

            if (params.pdmp) {
                PDMP (
                    ch_clfd_archives,
                    Integer.valueOf(params.max_chans),
                    Integer.valueOf(params.max_subints),
                )

                ch_fold_input
                    // input: ['name', Path('/path/to/name.eph'), Path(data), Path('/path/to/pubdir')], ...
                    .map { [ "${it[0]}_pdmp", it[3] ]}
                    // => ['name_pdmp', Path('/path/to/pubdir')], ...
                    .set { ch_pdmp_pubdir }

                PDMP.out.archive
                    // input: Path('/path/to/name_pdmp.ar'), ...
                    .map { [ it.baseName, it ] }
                    // => ['name_pdmp', Path('/path/to/name_pdmp.ar')], ...
                    .cross(ch_pdmp_pubdir)
                    // => [['name_pdmp', Path('/path/to/name_pdmp.ar')], ['name_pdmp', Path('/path/to/pubdir')]], ...
                    .map { [ it[0][0], it[0][1], it[1][1] ] }
                    // => ['name_pdmp', Path('/path/to/name_pdmp.ar'), Path('/path/to/pubdir')], ...
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
