/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT SUBWORKFLOWS/MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { DOWNLOAD            } from '../subworkflows/download'
include { REDUCE              } from '../subworkflows/reduce'
include { ANALYSIS_PREP       } from '../subworkflows/analysis_prep'
include { ANALYSIS_PREP_TRUNC } from '../subworkflows/analysis_prep'
include { ANALYSIS            } from '../subworkflows/analysis'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow VCSPIPE {

    if (params.cluster == null) {
        error("Cluster profile not specified.")
    } else {
        if (params.download) {
            DOWNLOAD ()
        } else if (params.reduce) {
            REDUCE ()
        } else if (params.analysis) {
            if (params.truncate) {
                ANALYSIS_PREP_TRUNC ()
                ANALYSIS (ANALYSIS_PREP_TRUNC.out.analysis_input)
            } else {
                ANALYSIS_PREP ()
                ANALYSIS (ANALYSIS_PREP.out.analysis_input)
            }
        } else {
            error("Pipeline mode not specified. Please use either '--download' or '--reduce' or '--analysis'.")
        }
    }
}
