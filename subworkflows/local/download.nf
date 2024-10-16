/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GS_VOLT   } from '../../modules/local/gs_volt'
include { GS_VIS    } from '../../modules/local/gs_vis'
include { MOVE_VIS  } from '../../modules/local/move_vis'
include { MOVE_VOLT } from '../../modules/local/move_volt'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DOWNLOAD {

    if (params.calid != null) {
        GS_VIS (params.calid)

        GS_VIS.out.jobs
            .splitCsv()
            .map { [ it[0], it[1] ] }
            .set { ch_asvo_jobs }

        MOVE_VIS (ch_asvo_jobs)
    }

    if (params.obsid != null) {
        GS_VOLT (
            params.obsid,
            params.offset,
            params.duration,
            params.num_dl_jobs
        )

        GS_VOLT.out.jobs
            .splitCsv()
            .map { [ it[0], it[1] ] }
            .set { ch_asvo_jobs }

        MOVE_VOLT (ch_asvo_jobs)
    }
}