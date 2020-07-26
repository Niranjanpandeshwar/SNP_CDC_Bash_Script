#!/bin/bash

# Parse input arguments
while getopts 'h:r:t:p:i:o:' OPTION; do
  
  case "$OPTION" in
    h)
      echo "script usage: $(basename $0) [-r reference_fasta_file] [-t S or P] [-p int] [-i input_folder] [-o output_folder]" >&2
      exit 1
      ;;

    r)
      Ref="$OPTARG"
      ;;

    t)
      Type="$OPTARG"
      ;;

    p)
      Ploidy="$OPTARG"
      ;;

    i)
      Input="$OPTARG"
      ;;

    o)
      Output="$OPTARG"
      ;;

    ?)
      echo "script usage: $(basename $0) [-r reference_fasta_file] [-t S or P] [-p int] [-i input_folder] [-o output_folder]" >&2
      exit 1
      ;;
    
  esac
done

# Exit code when a parameter is missed
if [ -z "$Ref" ] || [ -z "$Type" ] || [ -z "$Input" ] || [ -z "$Output" ] || [ -z "$Ploidy" ]

then
    echo "Missing required parameters" >&2
    echo "script usage: $(basename $0) [-r reference_fasta_file] [-t S or P] [-p int] [-i input_folder] [-o output_folder]" >&2
    exit 1
fi

# Check if reference file exists
if ! [ -f "$Ref" ]; then
    echo "Could not find $Ref"
    exit 1
fi

# Check if input directory exists
if ! [ -d "$Input" ]; then
    echo "Could not find $Input"
    exit 1
fi

# Check if output directory exists
if ! [ -d "$Output" ]; then
    echo "Could not find $Output"
    exit 1
fi

# Check if the input is single ended or paired
if   [ $Type == 'S' ]; then Inpnew="$Input"/*.fastq
elif [ $Type == 'P' ]; then Inpnew="$Input"/*_1.fastq
else echo "Invalid value in parameter 2. Please enter 'S' for single end reads or 'P' for paired end reads"
     exit 1
fi

# Load modules for the pipeline
ml bwa/0.7.17
ml samtools/1.10
ml gatk/4.1.7.0
ml picard/2.23.0
ml vcftools/0.1.17


# Index the reference FASTA file using BWA
bwa index "$Ref"

# Create a dictionary for the reference file
rm -f "${Ref%.*}".dict
picard CreateSequenceDictionary R="$Ref" O="${Ref%.*}".dict

# Generate reference index to be used in GATK
samtools faidx "$Ref"

# Proceed with the pipeline for all the files in the folder
for i in $Inpnew; do
	if   [ $Type == 'S' ]; then 
		
		Prefix=$(basename "$i" .fastq)

		# Create a subfolder to place all files for the particular read file
		mkdir -p "$Output"/"$Prefix"

		# Map input reads in FASTQ file to the reference file using BWA
		bwa mem -M "$Ref" "$Input"/"$Prefix".fastq > "$Output"/"$Prefix"/"$Prefix".sam

	elif [ $Type == 'P' ]; then 

		Prefix=$(basename "$i" _1.fastq)
	

		# Create a subfolder to place all files for the particular read file
		mkdir -p "$Output"/"$Prefix"

		# Map input reads in FASTQ file to the reference file using BWA
		bwa mem -M "$Ref" "$Input"/"$Prefix"_1.fastq "$Input"/"$Prefix"_2.fastq > "$Output"/"$Prefix"/"$Prefix".sam
	fi

# Convert  SAM to BAM format using Samtools
samtools view -bS "$Output"/"$Prefix"/"$Prefix".sam -o "$Output"/"$Prefix"/"$Prefix".bam

# Use picard to sort the BAM file using Picard
picard SortSam I="$Output"/"$Prefix"/"$Prefix".bam O="$Output"/"$Prefix"/"$Prefix"_sorted.bam SORT_ORDER=coordinate

# Mark and remove duplicates using Picard
picard MarkDuplicates I="$Output"/"$Prefix"/"$Prefix"_sorted.bam O="$Output"/"$Prefix"/"$Prefix"_nodup.bam REMOVE_DUPLICATES=true M="$Output"/"$Prefix"/"$Prefix"_nodup.txt

# Add Read groups using Picard
picard AddOrReplaceReadGroups I="$Output"/"$Prefix"/"$Prefix"_nodup.bam O="$Output"/"$Prefix"/"$Prefix"_rg.bam RGID=4 RGLB=lib1 RGPL=illumina RGPU=unit1 RGSM=20 CREATE_INDEX=true

# Performs variant calling using GATK
gatk --java-options "-Xmx5g" HaplotypeCaller -ploidy "$Ploidy" -R "$Ref" -I "$Output"/"$Prefix"/"$Prefix"_rg.bam -O "$Output"/"$Prefix"/"$Prefix"_gatk.vcf

# Filter and keep only SNPs using VCFtools
vcftools --vcf "$Output"/"$Prefix"/"$Prefix"_gatk.vcf --remove-indels --recode --recode-INFO-all --out "$Output"/"$Prefix"/"$Prefix"_snp

# Filter and keep only indels using VCFtools
vcftools --vcf "$Output"/"$Prefix"/"$Prefix"_gatk.vcf --keep-only-indels --recode --recode-INFO-all --out "$Output"/"$Prefix"/"$Prefix"_indel
done
