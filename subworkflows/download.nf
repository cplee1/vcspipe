/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GS_VOLT   } from '../modules/gs_volt'
include { GS_VIS    } from '../modules/gs_vis'
include { MOVE_VIS  } from '../modules/move_vis'
include { MOVE_VOLT } from '../modules/move_volt'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DOWNLOAD {

    if (params.calid != null) {
        GS_VIS (Integer.valueOf(params.calid))

        GS_VIS.out.jobs
            .splitCsv()
            .map { [ it[0], it[1] ] }
            .set { ch_asvo_jobs }

        MOVE_VIS (ch_asvo_jobs)
    }

    if (params.obsid != null) {
        GS_VOLT (
            Integer.valueOf(params.obsid),
            Integer.valueOf(params.offset),
            Integer.valueOf(params.duration),
            Integer.valueOf(params.num_dl_jobs)
        )

        GS_VOLT.out.jobs
            .splitCsv()
            .map { [ it[0], it[1] ] }
            .set { ch_asvo_jobs }

        MOVE_VOLT (ch_asvo_jobs)
    }
}