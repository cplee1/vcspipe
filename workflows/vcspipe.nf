/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT SUBWORKFLOWS/MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { DOWNLOAD  } from '../subworkflows/download'
include { REDUCE    } from '../subworkflows/reduce'

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
        } else {
            error("Pipeline mode not specified. Please use either '--download' or '--reduce'.")
        }
    }
}