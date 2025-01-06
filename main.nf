#!/usr/bin/env nextflow

// step read length
include { READ_LENGTH_ANALYSIS } from './modules/read_length'

workflow {
    bam_ch = channel.fromPath(params.bam)
    READ_LENGTH_ANALYSIS(bam_ch)
}
