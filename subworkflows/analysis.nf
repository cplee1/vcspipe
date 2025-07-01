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

    if (params.fluxcal && params.rmsynth) {
        FLUXCAL.out.results
            // input: ['label', Path('inputs.toml'), Path('results.toml')], ...
            .cross(RMSYNTH.out.results)
            // => [['label', Path('inputs.toml'), Path('results.toml')], ['label', Path('name_rm_prof.csv'), Path('name_rm_phi.csv')]], ...
            .map { [ it[0][0], it[0][2], it[1][1].splitCsv()[0][1] ] }
            // => ['label', Path('results.toml'), rm_prof], ...
            .cross(ch_analysis_input)
            // => [['label', Path('results.toml'), rm_prof], ['label', 'obsid', Path('/path/to/label.ar.clfd'), Path('/path/to/pubdir')]], ...
            .map { [ it[0][0], it[1][2], it[0][1], it[0][2], it[1][3] ] }
            // => ['label', Path('/path/to/label.ar.clfd'), Path('results.toml'), rm_prof, Path('/path/to/pubdir')], ...
            .set { ch_cal_input }

        CALIBRATE_ARCHIVE(ch_cal_input)
    }
}
