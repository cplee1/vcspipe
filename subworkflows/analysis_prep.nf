/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { TRUNCATE_ARCHIVE } from '../modules/truncate_archive'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ANALYSIS_PREP {
    main:

    // params.targets is a list of pulsar names and the directories containing
    // the archives
    // assume that the obsID is the second item of dirname.split('_')
    // assume that the archive has the extension .ar.clfd.pdmp
    // E.g. targets : J0437-4715@/path/to/J0437-4715_12345678_0000_0600
    //      archive : J0437-4715_12345678_0000_0600.ar.clfd.pdmp
    Channel
        .of(params.targets.split(' '))
        .map { str -> str.split('@') }
        .map { tup -> [tup[0], file(tup[1], type: 'dir', checkIfExists: true)] }
        .map { tup -> [tup[0], tup[1].baseName.split('_')[1], file("${tup[1].toString()}/*.ar.clfd.pdmp.trunc", type: 'file', checkIfExists: true), tup[1]] }
        // => ['SrcName', 'obsID', Path(archive), Path(pubDir)]
        .set { ch_analysis_input }

    emit:
    analysis_input = ch_analysis_input
}

workflow ANALYSIS_PREP_TRUNC {
    main:

    // params.targets is a list of pulsar names and the directories containing
    // the archives
    // assume that the obsID is the second item of dirname.split('_')
    // assume that the archive has the extension .ar.clfd.pdmp
    // E.g. targets : J0437-4715@/path/to/J0437-4715_12345678_0000_0600
    //      archive : J0437-4715_12345678_0000_0600.ar.clfd.pdmp
    Channel
        .of(params.targets.split(' '))
        .map { str -> str.split('@') }
        .map { tup -> [tup[0], file(tup[1], type: 'dir', checkIfExists: true)] }
        .map { tup -> [tup[0], tup[1].baseName.split('_')[1], file("${tup[1].toString()}/*.ar.clfd.pdmp", type: 'file', checkIfExists: true), tup[1]] }
        // => ['SrcName', 'obsID', Path(archive), Path(pubDir)]
        .set { ch_analysis_input }

    TRUNCATE_ARCHIVE(ch_analysis_input)

    emit:
    analysis_input = TRUNCATE_ARCHIVE.out.data
}
