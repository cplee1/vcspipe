# vcspipe
A Nextflow-based pipeline for reducing and processing MWA-VCS data.

## Installation
This pipeline is configured for use with Nextflow's inbuilt pipeline sharing feature. If you are using Pawsey's Setonix cluster, a configuration file has been made, and the pipeline can be run as-is. Otherwise, you will need to create a custom configuration file (using `conf/setonix.config` as a template).

Before using the pipeline, you must set up a Python virtual environment. On Setonix, this should be done as follows:
```bash
cd $MYSOFTWARE/setonix/python
mkdir venvs && cd venvs
module load python/3.11.6
python -m venv vcspipe
source vcspipe/bin/activate
python -m pip install psrqpy
```

## Usage
In general, the pipeline can be executed with:
```bash
nextflow run -latest cplee1/vcspipe -profile [PROFILES,...] [OPTIONS ...]
```
where `[PROFILES,...]` is a comma-separated list of Nextflow profiles defined in `nextflow.config`, and `[OPTIONS ...]` are the pipeline options, each of which begins with a double hypen (e.g. `--nbin 64`). The pipeline options only parse a single command line argument, so options with multiple inputs must be enclosed in quotes. For example, `--targets PSR1 PSR2` will only parse `'PSR1'`, whereas `--targets 'PSR1 PSR2'` will parse the string `'PSR1 PSR2'`.

## Workflows
Currently the pipeline contains two separate workflows: `--download` and `--reduce`. **One and only one of these workflows must be selected upon pipeline execution.** The `--download` workflow is for requesting ASVO downloads and moving the downloaded files into the required directory structure. The `--reduce` workflow is for beamforming and post-processing pulsar observations.

### Download Workflow
Before you use the download pipeline, ensure that you have defined the `$MWA_ASVO_API_KEY` environment variable.

A typical execution of the `--download` workflow looks like:
```bash
nextflow run -latest cplee1/vcspipe \
    -profile setonix \
    --download \
    --obsid OBSID \
    --offset OFFSET \
    --duration DURATION \
    --num_dl_jobs NUMJOBS
```
where `--obsid` is the MWA observation ID, `--offset` and `--duration` are the data download offset and duration (in seconds) to request from the ASVO, and `--num_dl_jobs` is the number of ASVO jobs to split the data download into. **Note that the individual job sizes (`$duration/$num_dl_jobs`) must be a multiple of 8 seconds, or ASVO will return an error.**

The first time that the `--download` workflow is executed, it will submit the jobs to ASVO and then exit. You can check the status of the jobs from the command line with `giant-squid list`. Once the jobs have finished downloading, run the pipeline again to move the files. The files will be placed in `$vcs_dir/$obsid/`. The default VCS directory is specified in the cluster configuration file; on Setonix the default is `$MYSCRATCH/vcs_downloads`. The default VCS directory can be overridden with `--vcs_dir PATH`.

An example workflow on Setonix may look like:
```bash
# Environment setup
module load nextflow/24.04.3
module load giant-squid/1.0.3

# First execution (queue ASVO jobs)
nextflow run -latest cplee1/vcspipe \
    -profile setonix \
    --download \
    --obsid 1267459328 \
    --offset 0 \
    --duration 1200 \
    --num_dl_jobs 2

# Wait until the download is completed
giant-squid list

# Second execution (move files to $vcs_dir/$obsid)
nextflow run -latest cplee1/vcspipe \
    -profile setonix \
    --download \
    --obsid 1267459328 \
    --offset 0 \
    --duration 1200 \
    --num_dl_jobs 2
```

### Reduce Workflow
Before you use start processing the data, **it is essential that all of the data and metadata are in the directories expected by the pipeline**. A summary of the expected files is provided below:

| Description          | Filename                 | Directory                           |
|----------------------|--------------------------|-------------------------------------|
| Combined VCS data    | *.dat or *.sub           | ${vcs_dir}/${obsid}/combined/       |
| VCS metadata         | ${obsid}.metafits        | ${vcs_dir}/${obsid}/                |
| Calibration metadata | ${calid}.metafits        | ${vcs_dir}/cal/${calid}/            |
| Calibration solution | hyperdrive_solutions.bin | ${vcs_dir}/cal/${calid}/hyperdrive/ |

In general, there are two situation in which the `--reduce` workflow is useful:

1. You want to beamform and fold on a known, catalogued pulsar
2. You want to beamform on a pointing without any post-processing

In both cases, you must specify whether you want the pipeline to process the data in PSRFITS or VDIF format. This is done by selecting _either_ the `psrfits` _or_ the `vdif` profile upon execution. PSRFITS data can be post-processed with `--prepfold` and/or `--dspsr' and '--pdmp`, whereas VDIF data can _only_ be post-processed with `--dspsr/--pdmp`.

A typical pulsar-mode `--reduce` execution for PSRFITS data looks like:
```bash
nextflow run -latest cplee1/vcspipe \
    -profile setonix,psrfits \
    --obsid OBSID \
    --low_chan LOWCHAN \
    --num_chan NUMCHAN \
    --calid CALID \
    --prepfold --dspsr --pdmp
```
Wheras for VDIF data a typical execution looks like:
```bash
nextflow run -latest cplee1/vcspipe \
    -profile setonix,vdif \
    --obsid OBSID \
    --low_chan LOWCHAN \
    --num_chan NUMCHAN \
    --calid CALID \
    --dspsr --pdmp
```
Any or all of `--prepfold`, `--dspsr`, and `--pdmp` can be excluded, however `--pdmp` will not run without `--dspsr`. **Note that the `--reduce` flag is included in the `psrfits` and `vdif` profiles, so it does not need to be provided again.**

There are several post-processing pipeline options which can be specified. For example `--nbin NBIN` changes the _maximum_ number of phase bins to fold into. The actual number of phase bins will be reduced if the sampling rate is insufficient for the specified time/freq resolution (this is only really applicable to millisecond pulsars). To see all available options, see the `nextflow.config` file.

For convenience, a `smart` profile has been provided which specifies the frequency setup of the SMART survey, i.e. `--low_chan 109 --num_chan 24`.

Lets say you want to beamform on two normal pulsars in the first 10 minutes of SMART survey observation `1255444104`, with calibration observation `1255443816`, and post-process with both `prepfold` and `dspsr`. An example workflow on Setonix may look like:
```bash
# Start a new screen session
screes -S beamforming

# Environment setup
module load nextflow/24.04.3

# Run the pipeline
nextflow run -latest cplee1/vcspipe \
    -profile setonix,psrfits,smart \
    --obsid 1255444104 \
    --calid 1255443816 \
    --targets 'J0034-0721@0-600 J0036-1033@0-600' \
    --prepfold --dspsr --pdmp

# Detach from screen session with `Ctrl+a d`

# Reattach to screen session
screen -r beamforming
```

If you are beamforming on a pointing without any intention to post-process (such as a pulsar candidate), the command may look like:
```bash
nextflow run -latest cplee1/vcspipe \
    -profile setonix,psrfits,smart \
    --obsid 1255444104 \
    --calid 1255443816 \
    --targets '00:34:08.87_-07:21:53.40@0-600 00:36:15.01_-10:33:14.2@0-600'
```