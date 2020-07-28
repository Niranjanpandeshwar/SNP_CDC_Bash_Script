# SNP Variant Calling Pipeline

## Customizing scripts
### BWA - Burrows Wheeler Aligner

Basic script to perform mapping
```
bwa mem sample.fasta read1.fastq read2.fastq > output.sam
```

Modify script to add a parameter for threads
```
bwa -t 10 mem sample.fasta read1.fastq read2.fastq > output.sam
```
BWA mem with mismatch penalty
```
bwa -t 10 -B 6 mem sample.fasta read1.fastq read2.fastq > output.sam
```

## Instructions to run the pipeline through shell script
1. Clone the git repository using the command below. A folder named SNP will be in your current working directory.
```
git clone https://gitlab.com/Niranjanpandeshwar/snp
```
2. Change directory into snp folder
```
cd snp
```
3. Run the "ll" command to see all the files and folders. You should see 3 folders named "input", "reference" and "output" and a file named snp_script.sh. The input folder has some test fastq files. reference folder has a test fasta reference file. The output folder has the expected files. 
```
ll
```
4. Run the script with the command below
```
./snp_script.sh -r reference/wildtype.fna -t p -p 2 -i input -o output
```
5. All files in the input folder will be processed. The output is available in output folder. 
```
cd output
```
