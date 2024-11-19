/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT SUBWORKFLOWS/MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { DOWNLOAD  } from '../subworkflows/download'
include { CALIBRATE } from '../subworkflows/calibrate'
include { REDUCE    } from '../subworkflows/reduce'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow VCSPIPE {

    if (params.cluster == null) {
        System.err.println("ERROR: Cluster not specified.")
    }

    if (params.cluster != null) {
        if (params.download) {
            DOWNLOAD ()
        }

        if (params.calibrate) {
           CALIBRATE ()
        }

        if (params.reduce) {
            REDUCE ()
        }
    }
}
