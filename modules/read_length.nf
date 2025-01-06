process COUNT_READ_LENGTHS {
    publishDir "${params.outdir}/read_length_distribution/counts", mode: 'copy'
    
    label 'samtools'
    
    input:
    path bam
    
    output:
    path "${bam.baseName}.length_counts.txt"
    
    script:
    """
    samtools view -F 4 ${bam} | \
    awk '{print length(\$10)}' | \
    sort -n | \
    uniq -c | \
    awk '{sub(/^[ ]+/,"");print }' > ${bam.baseName}.length_counts.txt
    """
}

process PLOT_READ_LENGTHS {
    publishDir "${params.outdir}/read_length_distribution", mode: 'copy'
    
    label 'r'
    
    input:
    path counts
    
    output:
    tuple path("all_read_length.pdf"), path("all_read_length.csv"), emit: plots
    
    script:
    """
    #!/usr/bin/env Rscript
    
    # Read count data
    data <- read.table("${counts}", header=FALSE)
    colnames(data) <- c("count", "length")
    
    # Create plot using base R
    pdf("all_read_length.pdf", width=7, height=5)
    par(mar=c(5.1,6.1,4.1,2.1))
    barplot(
        data\$count,
        names.arg=data\$length,
        las=1,
        xlab='Read length [nt]',
        ylab='Count',
        cex.names=1.2,
        cex.lab=1.2,
        cex.axis=1.2
    )
    dev.off()
    
    # Save data
    write.csv(data, "all_read_length.csv", row.names=FALSE)
    """
}

workflow READ_LENGTH_ANALYSIS {
    take:
    bam
    
    main:
    counts = COUNT_READ_LENGTHS(bam)
    plots = PLOT_READ_LENGTHS(counts)
    
    emit:
    counts = counts
    plots = PLOT_READ_LENGTHS.out.plots
}
