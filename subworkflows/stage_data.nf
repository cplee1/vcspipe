/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GET_OBS_METADATA } from '../modules/get_obs_metadata'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow STAGE_DATA {
    main:

    // List of pulsar names and the file locations
    // E.g. 'J0437-4715@/path/to/J0437-4715_files'
    Channel
        // input: 'nameA@pathA nameB@pathB ...'
        .of(params.targets.split(' '))
        // => 'nameA@pathA', 'nameB@pathB', ...
        .map { str -> str.split('@') }
        // => ['nameA', 'pathA'], ['nameB', 'pathB'], ...
        .map { tup -> [tup[0], file(tup[1], type: 'dir', checkIfExists: true)] }
        // => ['nameA', Path('pathA')], ['nameB', Path('pathB')], ...
        .map { tup -> [tup[0], file("${tup[1].toString()}/*.fits", type: 'file', checkIfExists: true)] }
        // => ['nameA', List<Path>], ['nameB', List<Path>], ...
        .set { ch_beamformed_data }

    GET_OBS_METADATA(ch_beamformed_data)

    emit:
    targets = GET_OBS_METADATA.out.targets
    data = GET_OBS_METADATA.out.beamformed_data
}
