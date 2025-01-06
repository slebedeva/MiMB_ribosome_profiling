# ZI pipeline as per their github repo 

# specify output directory
outdir=example_output
mkdir -p $outdir 

# unzip fastq input
if [ ! -f example_data/sequencing_data/rpf.fastq ]; then
    gunzip example_data/sequencing_data/rpf.fastq.gz
fi

# load necessary modules
#ml python/3.8.8_gnu740_jupyter bowtie samtools/1.18 bedtools/2.31.0 #R/4.4.2_system

# perform adapter cutting and mapping
if [ ! -f $outdir/mapping/rpf.sort.bam ]; then
    apptainer exec --bind /projects/ag-tresch:/projects/ag-tresch --env-file ~/apptainer_env $Svetlana/containers/rstudio_devel_4_4_2.sif Rscript mapping.R example_data/sequencing_data/ $outdir example_data/genome_data/E_coli_genome.fa
fi

# get read distribution info and plots
if [ ! -f $outdir/read_length_distribution/all_read_length.csv ]; then
    apptainer exec --bind /projects/ag-tresch:/projects/ag-tresch --env-file ~/apptainer_env $Svetlana/containers/rstudio_devel_4_4_2.sif Rscript read_length_distribution.R $outdir/mapping/ $outdir
fi

# determine the genes with good expression levels
if [ ! -f $outdir/highest_expressed_genes/highest_expressed_genes.bed ]; then
    apptainer exec --bind /projects/ag-tresch:/projects/ag-tresch --env-file ~/apptainer_env $Svetlana/containers/rstudio_devel_4_4_2.sif Rscript highest_expressed_genes.R $outdir/mapping/rpf.sort.bam example_data/genome_data/E_coli_genes.bed $outdir 0.1
fi

# prepare the BED file
if [ ! -f $outdir/highest_expressed_genes/highest_expressed_genes_plus_50nt.bed ]; then
    apptainer exec --bind /projects/ag-tresch:/projects/ag-tresch --env-file ~/apptainer_env $Svetlana/containers/rstudio_devel_4_4_2.sif Rscript prepare_coverage.R $outdir/highest_expressed_genes/highest_expressed_genes.bed
fi

# generate plot to show coverage of RPFs
if [ ! -f $outdir/coverage_start_stop/coverage_rpf.sort.pdf ]; then
    apptainer exec --bind /projects/ag-tresch:/projects/ag-tresch --env-file ~/apptainer_env $Svetlana/containers/rstudio_devel_4_4_2.sif Rscript coverage_start_stop.R $outdir/mapping/ $outdir/highest_expressed_genes/highest_expressed_genes_plus_50nt.bed $outdir
fi

# split reads by length, 5' assignment for read length of 24 to 30 nucleotides
if [ ! -f $outdir/calibration/calibration_5prime_config.csv ]; then
    apptainer exec --bind /projects/ag-tresch:/projects/ag-tresch --env-file ~/apptainer_env $Svetlana/containers/rstudio_devel_4_4_2.sif Rscript split_by_length.R $outdir/mapping/ $outdir/ 5prime 24-30
fi

# generate the plot to calibrate the RPFs
if [ ! -f $outdir/calibration/calibration_rpf_28_firstBase.sort.pdf ]; then
    apptainer exec --bind /projects/ag-tresch:/projects/ag-tresch --env-file ~/apptainer_env $Svetlana/containers/rstudio_devel_4_4_2.sif Rscript calibration_count_plot.R $outdir/calibration/split_by_length/ $outdir/highest_expressed_genes/highest_expressed_genes_plus_50nt.bed $outdir/
fi

# at this point you need to manually enter offsets
# -s = silent (do not show what user typed) 
# -p = display prompt 
#read -sp "Enter offset for length 24: " offset
echo "######################################################"
echo "Enter offsets into calibration/calibration_config.csv!"
read -p "Press Enter to continue" </dev/tty #redirecting back to shell
echo "######################################################"

# calibrate the reads accoring to manually determined offsets using the calibration_config.csv in the $outdir/calibration folder
if [ ! -f $outdir/calibration/calibrated/rpf_24_calibrated.bam ]; then
    apptainer exec --bind /projects/ag-tresch:/projects/ag-tresch --env-file ~/apptainer_env $Svetlana/containers/rstudio_devel_4_4_2.sif Rscript calibrate_reads.R $outdir/mapping/ example_data/calibration_5prime_config.csv $outdir
fi

# merge different read length after calibration
if [ ! -f $outdir/calibration/calibrated/rpf_calibrated.bam ]; then
    apptainer exec --bind /projects/ag-tresch:/projects/ag-tresch --env-file ~/apptainer_env $Svetlana/containers/rstudio_devel_4_4_2.sif Rscript merge_reads.R $outdir/calibration/calibrated/
fi

# generate a coverage plot using precisely calibrated reads
if [ ! -f $outdir/coverage_start_stop/coverage_rpf.sort.pdf ]; then
    apptainer exec --bind /projects/ag-tresch:/projects/ag-tresch --env-file ~/apptainer_env $Svetlana/containers/rstudio_devel_4_4_2.sif Rscript coverage_start_stop.R $outdir/calibration/calibrated/ $outdir/highest_expressed_genes/highest_expressed_genes_plus_50nt.bed $outdir/calibrated_coverage
fi
