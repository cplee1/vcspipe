/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FLUXCAL } from '../modules/fluxcal'
include { RMSYNTH } from '../modules/rmsynth'

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
}
