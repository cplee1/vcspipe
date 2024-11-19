/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PARSE_TARGETS  } from '../modules/parse_targets'
include { PREPARE_INPUTS } from '../modules/prepare_inputs'
include { VCSBEAM        } from '../modules/vcsbeam'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow REDUCE {

    Channel
        .of(params.targets.split(' '))
        .set { ch_targets }

    PARSE_TARGETS(ch_targets)

    PARSE_TARGETS.out.names_pointings
        .splitCsv(header: true)
        .collate(
            { params.vdif ? Integer.valueOf(1) : Integer.valueOf(params.num_beams) }
        )
        // Input array:      [ [name0, pointing0], ..., [nameN, pointingN] ]
        // Transposed array: [ [name0, ..., nameN], [pointing0, ..., pointingN] ]
        .map { GroovyCollections.transpose(it) }
        .set { ch_names_pointings }

    PREPARE_INPUTS(ch_names_pointings)

    VCSBEAM (
        PREPARE_INPUTS.out.pointings,
        Integer.valueOf(params.offset),
        Integer.valueOf(params.duration),
        Integer.valueOf(params.low_chan),
        file("${params.vcs_dir}/${params.obsid}/combined", type = 'dir', checkIfExists = true),
        file("${params.vcs_dir}/${params.obsid}/${params.obsid}.metafits", type = 'file', checkIfExists = true),
        file("${params.vcs_dir}/${params.obsid}/cal/${params.calid}/${params.calid}.metafits", type = 'file', checkIfExists = true),
        file("${params.vcs_dir}/${params.obsid}/cal/${params.calid}/hyperdrive/hyperdrive_solutions.bin", type = 'file', checkIfExists = true),
        { params.vdif ? "-v" : "-p" },
    )

    VCSBEAM.out.beamformed_data
        .flatten()
        .set { ch_beamformed_data }
}