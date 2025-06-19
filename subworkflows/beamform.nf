/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PARSE_TARGETS  } from '../modules/parse_targets'
include { PREPARE_INPUTS } from '../modules/prepare_inputs'
include { VCSBEAM        } from '../modules/vcsbeam'
include { TAR            } from '../modules/tar'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow BEAMFORM {
    main:

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

    emit:
    targets = ch_targets
    tarballs = TAR.out.tarballs
}