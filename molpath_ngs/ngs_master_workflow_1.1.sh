#!/bin/sh
#$ -S /bin/bash
#$ -cwd
#$ -V
#$ -N ngs_master_workflow_v1.1
#$ -M stephen.newhouse@kcl.ac.uk
#$ -m beas
#$ -pe multi_thread 1
#$ -l h_vmem=1G
#$ -p -0.99999999999999999999999999999999999999999999999999999999999999999
#$ -j yes
#------------------------------------------------------------------------#


#########################################################################
# -- Authors: Stepgen Newhouse, Amos Folarin, Aditi Gulati              #
# -- Organisation: KCL/SLaM/NHS                                         #
# -- Email: stephen.j.newhouse@gmail.com, amosfolarin@gmail.com         #
# -- Verion: 1.10                                                       #
# -- Date: 11/09/2013                                                   #
# -- DESC: NGS pipeline to perform SE/PE Alignments & GATK cleaning     #
#########################################################################

# called using "Rscript call_ngs_master_workflow.R <config_file>"

# this calls the following with options read in from R and fired off using R's system() command

# qsub ngs_master_workflow.sh <fastq_prefix> <sample_name> <qual_type> <RGID> <RGLB> <RGPL> <RGPU> <RGSM> <RGCN> <RGDS> <RGDT> <PE>

# ALL OPTIONS REQUIRED
# -- fastq_prefix=string	fastq prefix for Sample ID ie <fastq_prefix>_1.fastq <fastq_prefix>_2.fastq
# -- sample_name=string		Sample ID
# -- qual_type=string		Base quality coding for novoalign ie STFQ, ILMFQ, ILM1.8
# -- RGID=String		Read Group ID Required. <PROJECT_NAME>
# -- RGLB=String		Read Group Library Required. <PATIENT_ID>.<RGPL>.<>
# -- RGPL=String		Read Group platform (e.g. illumina, solid) Required.
# -- RGPU=String		Read Group platform unit (eg. run barcode) Required.
# -- RGSM=String		Read Group sample name Required. PATIENT_ID
# -- RGCN=String		Read Group sequencing center name Required.
# -- RGDS=String		Read Group description Required.
# -- RGDT=Iso8601Date		Read Group run date Required.
# -- PE=1 or 0			Indicates PE or SE

#------------------------------------------------------------------------#
# Set environmental variables required for child processes (all )
#------------------------------------------------------------------------#

#######
# QUE #
#######

queue_name="short.q,long.q"
email_contact="stephen.newhouse@kcl.ac.uk"

#####################
# mem and cpu vars ##
#####################

## Novoalign
export novo_cpu=8
export novo_mem=3

## Java & Picardtools
export sge_h_vmem=8
export java_mem=6

## Java & GATK
export gatk_h_vmem=8
export gatk_java_mem=6

###############
## ngs tools ##
###############

export ngs_picard="/share/apps/picard-tools_1.91/jar"
export ngs_gatk="/share/apps/gatk_2.5-2"
export ngs_novo="/share/apps/novocraft_20130415/bin" ## Novoalign V3.00.03
export ngs_samtools="/share/apps/samtools_0.1.18/bin"

##################
## pipeline dir ##
##################

export ngs_pipeline="/scratch/project/pipelines/ngs_pipeline_dev/ngs_dev_sjn_tmp"

######################
## reference genomes #
######################

export reference_genome_novoindex="/scratch/data/reference_genomes/gatk_resources/b37/human_g1k_v37.fasta.novoindex"

export reference_genome_seq="/scratch/data/reference_genomes/gatk_resources/b37/human_g1k_v37.fasta"

############################
## ref vcf files for gatk ##
############################

## needs updating!!!!!!

# indels
export b37_1000G_biallelic_indels="/scratch/data/reference_genomes/gatk_resources/b37/1000G_biallelic.indels.b37.vcf"
export b37_Mills_Devine_2hit_indels_sites="/scratch/data/reference_genomes/gatk_resources/b37/Mills_Devine_2hit.indels.b37.sites.vcf"
export b37_Mills_Devine_2hit_indels="/scratch/data/reference_genomes/gatk_resources/b37/Mills_Devine_2hit.indels.b37.vcf"

# snps
export b37_1000G_omni2_5="/scratch/data/reference_genomes/gatk_resources/b37/1000G_omni2.5.b37.vcf"
export b37_hapmap_3_3="/scratch/data/reference_genomes/gatk_resources/b37/hapmap_3.3.b37.sites.vcf"
export b37_dbsnp_132_excluding_sites_after_129="/scratch/data/reference_genomes/gatk_resources/b37/dbsnp_132.b37.excluding_sites_after_129.vcf"
export b37_dbsnp_132="/scratch/data/reference_genomes/gatk_resources/b37/dbsnp_132.b37.vcf"


#######################
## Path to fastq dir ##
#######################

export fastq_dir="/scratch/project/pipelines/ngs_pipeline_dev/aditi_fastq"

###########################
## path to final aln dir ##
###########################

export aln_dir="/scratch/project/pipelines/ngs_pipeline_dev/ngs_molpath_sjn"

###########################
## path to tmp aln dir   ##
###########################

export ngstmp="/home/snewhousebrc/scratch/ngs_temp"

#############################
## get and set all options ##
#############################

fastq_prefix=${1}
sample_name=${2}.${5}.${6}
qual_type=${3}  ## Base quality coding for novoalign ie STFQ, ILMFQ, ILM1.8
mRGID=${4}	#Read Group ID Required.
mRGLB=${5}	#Read Group Library Required.
mRGPL=${6}	#Read Group platform (e.g. illumina, solid,IONTORRENT) Required.
mRGPU=${7}	#Read Group platform unit (eg. run barcode) Required.
mRGSM=${8}	#Read Group sample name Required.
mRGCN=${9}	#Read Group sequencing center name Required.
mRGDS=${10}	#Read Group description Required.
mRGDT=${11}	#Read Group run date Required.
mPE=${12}

#------------------------------------------------------------------------------#
# END setting environmental variables required for child processes (all )
#------------------------------------------------------------------------------#


##############################
## make sample dir for data ##
##############################

## temp dir
mkdir ${ngstmp}/${sample_name}_temp

## final data dir
mkdir ${aln_dir}/${sample_name}

sample_temp=${ngstmp}/${sample_name}_temp

sample_dir=${aln_dir}/${sample_name}

######################################
# moving to sample directory #########
######################################

echo "moving to sample directory "  ${sample_dir}

cd ${sample_dir}



##############################
## START ALIGNMENT PIPELINE ##
##############################

#----------------------------------------------------------------------#
# 1. Align PE or SE data 
#----------------------------------------------------------------------#
echo ">>>>>" `date` " :-> " "Aligning PE data "

if [ ${mPE} -eq 1 ]; then

	qsub -q ${queue_name} -N novoalign.${sample_name} -l h_vmem=${novo_mem}G -pe multi_thread ${novo_cpu} -M ${email_contact} -m beas \
	${ngs_pipeline}/ngs_novoalign.${qual_type}.PE.sh \
	${fastq_prefix} \
	${sample_name} \
	${sample_dir};
	
else

	qsub -q ${queue_name} -N novoalign.${sample_name} -l h_vmem=${novo_mem}G -pe multi_thread ${novo_cpu} -M ${email_contact} -m beas \
	${ngs_pipeline}/ngs_novoalign.${qual_type}.SE.sh \
	${fastq_prefix} \
	${sample_name} \
	${sample_dir};
	
fi

#----------------------------------------------------------------------#
# 2. sam2bam
#----------------------------------------------------------------------#

echo ">>>>>" `date` " :-> " "Converting Novoalign SAM to BAM and indexing"

qsub -q ${queue_name} -N sam2bam.${sample_name} -hold_jid novoalign.${sample_name} -l h_vmem=${sge_h_vmem}G -pe multi_thread 1 -M ${email_contact} -m beas \
${ngs_pipeline}/ngs_sam2bam.sh ${sample_name} ${sample_dir};


#----------------------------------------------------------------------#
# 3. SortSam
#----------------------------------------------------------------------#

qsub -q ${queue_name} -N SortSam.${sample_name} -hold_jid sam2bam.${sample_name}  -l h_vmem=${sge_h_vmem}G -pe multi_thread 1 -M ${email_contact} -m beas \
${ngs_pipeline}/ngs_SortSam.sh \
${sample_name} \
${sample_dir} \
${sample_temp};

#----------------------------------------------------------------------#
# 4. AddOrReplaceReadGroups 
#----------------------------------------------------------------------#

echo ">>>>>" `date` " :-> " "Running AddOrReplaceReadGroups" 

qsub -q ${queue_name} -N AddOrReplaceReadGroups.${sample_name} -hold_jid SortSam.${sample_name} -l h_vmem=${sge_h_vmem}G -pe multi_thread 1 -M ${email_contact} -m beas \
${ngs_pipeline}/ngs_AddOrReplaceReadGroups.sh \
${sample_name} \
${sample_dir} \
${sample_temp} \
${mRGID} ${mRGLB} ${mRGPL} ${mRGPU} ${mRGSM} ${mRGCN} ${mRGDS} ${mRGDT};


#----------------------------------------------------------------------#
# 5. MarkDuplicates
#----------------------------------------------------------------------#

echo ">>>>>" `date` " :-> " "Running MarkDuplicates"

qsub -q ${queue_name} -N MarkDuplicates.${sample_name} -hold_jid AddOrReplaceReadGroups.${sample_name} -l h_vmem=${sge_h_vmem}G  -pe multi_thread 1 -M ${email_contact} -m beas \
${ngs_pipeline}/ngs_MarkDuplicates.sh \
${sample_name} \
${sample_dir} \
${sample_temp};

#----------------------------------------------------------------------#
# 6. Clean up aln sample dir
#----------------------------------------------------------------------#

echo ">>>>>" `date` " :-> " "Running Clean Up 01"

qsub -q ${queue_name} -N rmvIntermediateSAMs.${sample_name} -hold_jid MarkDuplicates.${sample_name} -l h_vmem=1G -M ${email_contact} -m beas \
${ngs_pipeline}/ngs_rmvdIntermediateSAMs.sh \
${sample_name} \
${sample_dir} \
${sample_temp};

##############################
## END ALIGNMENT PIPELINE   ## 
##############################


#########################
## BEGIN GATK CLEANING ##
#########################

#----------------------------------------------------------------------#
# 7. RealignerTargetCreator
#----------------------------------------------------------------------#

echo ">>>>>" `date` " :-> " "Running RealignerTargetCreator"

qsub -q ${queue_name} -N RealignerTargetCreator.${sample_name} -hold_jid MarkDuplicates.${sample_name} -l h_vmem=${gatk_h_vmem}G -M ${email_contact} -m beas \
${ngs_pipeline}/ngs_RealignerTargetCreator.sh \
${sample_name} \
${sample_dir} \
${sample_temp};


#----------------------------------------------------------------------#
# 8. IndelRealigner
#----------------------------------------------------------------------#

echo ">>>>>" `date` " :-> " "Running IndelRealigner"

qsub -q ${queue_name} -N IndelRealigner.${sample_name} -hold_jid RealignerTargetCreator.${sample_name} -l h_vmem=${gatk_h_vmem}G -M ${email_contact} -m beas \
${ngs_pipeline}/ngs_IndelRealigner.sh \
${sample_name} \
${sample_dir} \
${sample_temp};


#----------------------------------------------------------------------#
# 9. BaseRecalibrator before recal
#----------------------------------------------------------------------#

echo ">>>>>" `date` " :-> " "Running BaseRecalibrator before QUAL SCORE RECALIBRATION"

qsub -q ${queue_name} -N BaseRecalibrator_before.${sample_name} -hold_jid IndelRealigner.${sample_name} -l h_vmem=${gatk_h_vmem}G -M ${email_contact} -m beas \
${ngs_pipeline}/ngs_BaseRecalibrator_before.sh \
${sample_name} \
${sample_dir} \
${sample_temp};


#----------------------------------------------------------------------#
# 10. PrintReads = QUAL SCORE RECALIBRATION
#----------------------------------------------------------------------#

echo ">>>>>" `date` " :-> " "Running PrintReads > QUAL SCORE RECALIBRATION "

qsub -q ${queue_name} -N PrintReads_BQSR.${sample_name} -hold_jid BaseRecalibrator_before.${sample_name} -l h_vmem=${gatk_h_vmem}G -M ${email_contact} -m beas \
${ngs_pipeline}/ngs_PrintReads_BQSR.sh \
${sample_name} \
${sample_dir} \
${sample_temp};


#----------------------------------------------------------------------#
# 11. BaseRecalibrator after recal
#----------------------------------------------------------------------#

echo ">>>>>" `date` " :-> " "Running BaseRecalibrator after QUAL SCORE RECALIBRATION"

qsub -q ${queue_name} -N BaseRecalibrator_after.${sample_name} -hold_jid PrintReads_BQSR.${sample_name} -l h_vmem=${gatk_h_vmem}G -M ${email_contact} -m beas \
${ngs_pipeline}/ngs_BaseRecalibrator_after.sh \
${sample_name} \
${sample_dir} \
${sample_temp};


#----------------------------------------------------------------------#
# 12. AnalyzeCovariates before & after recal
#----------------------------------------------------------------------#

echo ">>>>>" `date` " :-> " "Running AnalyzeCovariates"

qsub -q ${queue_name} -N BaseRecalibrator_after.${sample_name} -hold_jid PrintReads_BQSR.${sample_name} -l h_vmem=${gatk_h_vmem}G -M ${email_contact} -m beas \
${ngs_pipeline}/ngs_AnalyzeCovariates_before_and_after_BQSR.sh \
${sample_name} \
${sample_dir} \
${sample_temp};


#########################
## END GATK CLEANING   ##
#########################






































