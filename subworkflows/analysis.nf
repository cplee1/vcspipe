/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FLUXCAL           } from '../modules/fluxcal'
include { RMSYNTH           } from '../modules/rmsynth'
include { CALIBRATE_ARCHIVE } from '../modules/calibrate_archive'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ANALYSIS {
    take:
    ch_analysis_input

    main:
    if (params.fluxcal) {
        FLUXCAL(ch_analysis_input)
    }

    if (params.rmsynth) {
        ch_analysis_input
            // input: ['label', 'obsid', Path('/path/to/label.ar.clfd'), Path('/path/to/pubdir')], ...
            .map { [ it[0], it[2], it[3] ] }
            // => ['label', Path('/path/to/label.ar.clfd'), Path('/path/to/pubdir')], ...
            .set { ch_rmsynth_input }

        RMSYNTH(ch_rmsynth_input)
    }

    if (params.fluxcal && params.rmsynth && params.calibrate) {
        FLUXCAL.out.results
            // input: ['label', Path('*_fluxcal_results.toml')], ...
            .cross(RMSYNTH.out.results)
            // => [['label', Path('*_fluxcal_results.toml')], ['label', Path('*_rm_results.toml')]], ...
            .map { [ it[0][0], it[0][1], it[1][1] ] }
            // => ['label', Path('*_fluxcal_results.toml'), Path('*_rm_results.toml')], ...
            .cross(ch_analysis_input)
            // => [['label', Path('*_fluxcal_results.toml'), Path('*_rm_results.toml')], ['label', 'obsid', Path('/path/to/label.ar.clfd'), Path('/path/to/pubdir')]], ...
            .map { [ it[0][0], it[1][2], it[0][1], it[0][2], it[1][3] ] }
            // => ['label', Path('/path/to/label.ar.clfd'), Path('*_fluxcal_results.toml'), Path('*_rm_results.toml'), Path('/path/to/pubdir')], ...
            .set { ch_cal_input }

        CALIBRATE_ARCHIVE(ch_cal_input)
    }
}
