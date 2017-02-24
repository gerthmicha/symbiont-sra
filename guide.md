## Detailed guide to replicate data retrieval and analyses from [Gerth & Hurst 2016](https://github.com/gerthmicha/symbiont-sra)

This guide lists the steps we used to screen short read sequencing data from honey bees (*Apis* ssp.) for genomic data of their associated microbes. In general, this is also transferable to retrieving symbiont data from other Eukaryote sequencing projects. All files mentioned can be accessed via https://github.com/gerthmicha/symbiont-sra. The following tools were used (alternatives in brackets):

+ [NCBI SRA tools](https://github.com/ncbi/sra-tools)
+ [NCBI Batch Entrez](http://www.ncbi.nlm.nih.gov/sites/batchentrez)
+ [NextGenMap](http://cibiv.github.io/NextGenMap/) (any other short read mapper)
+ [samtools](http://www.htslib.org/)
+ [bam2fastx](http://manpages.ubuntu.com/manpages/trusty/en/man1/bam2fastx.1.html)
+ [SPAdes](http://bioinf.spbau.ru/spades) (any other short read assembler)
+ [NCBI BLAST](https://blast.ncbi.nlm.nih.gov/Blast.cgi)
+ [blobtools](https://github.com/DRL/blobtools)
+ [MEGAHIT](https://github.com/voutcn/megahit) (other assembler)
---
### Workflow
###### Compile list of SRA experiments
+ Search NCBI's short read archive (http://www.ncbi.nlm.nih.gov/sra) for experiments of interest and download summary files. E.g., WGS studies from *Apis*, targeting DNA.
+ Retrieve run accession numbers associated with each experiment from this file.

###### Download of short read files
+ Using ```fastq-dump``` from NCBI's SRA tools , download all reads and convert from sra format into zipped fastq files. This can be parallelized, e.g., with ```xargs -P [# cores]```:
```shell
cat sra_accession_list.txt | xargs -n 1 -P 3 -I{} fastq-dump -O reads_folder --gzip --split-3 {}
```

###### Compile reference sequences
+ For each symbiont/microbe to be searched for, include a single signature sequence into a fasta file (e.g., bacterial 16S).

###### Mapping
+ Map all downloaded reads to reference sequences.
+ Paired-end mapping of all read files stored in the current folder to the reference fasta file:
```shell
ls *_* | cut -f1 -d'_' | sort -u | xargs -I{} -n 1 ngm --bam --no-unal -1 {}_1.fastq.gz -2 {}_2.fastq.gz -r reference.fas -o mapping/{}.bam -g -t 3 -i 0.95
```
+ Single-end mapping:
```shell
ls *.fastq | cut -d'.' -f1 | sort -u | xargs -I{} -n 1 ngm --bam --no-unal -q {}.fastq.gz -r ../reference.fas -o mapping/{}.bam -g -t 3 -i 0.95
```
In these examples, all mapping files in bam format are stored in a folder 'mapping'. Sensitivity of mapping can be controlled with ```-i``` in NextGenMap (here: ```-i 0.95```=95%). In order to save disc space, only aligned reads are stored in the bam files (```--no-unal```).

###### Retreive mapping results
+ Sort all bam files in current folder, count number of mapped reads, write results to file:
```shell
for i in *.bam; do samtools sort  ${i} $(basename ${i} .bam).sort; done
for i in *.sort.bam; do samtools view -c ${i} >> mapping_count.txt; done
ls *.sort.bam >> names.txt
paste names.txt mapping_count.txt >> mapping_results.txt
```
In this example, all bam files are sorted with a for loop (the unsorted bam files can be discarded afterwards in order to save disk space). Next, another loop will count the mapped reads in each of the bam files. Finally, counts will be written with the names of the corresponding bam files into a new file.

###### Extract microbe reads from mapping files
+ Extract reads from bam files for mappings in which at least 1000 reads were mapped:
```shell
awk '$2 > 999' mapping_results.txt | cut -f1 | cut -f1 -d'.' | xargs -n 1 -P 3 -I{} bam2fastx -Q -q -A -o {}.fq {}.bam
```
Here, the names of the bam files with more 1000 or more mapped reads will be extracted using ```awk```. The names are then piped to the ```bam2fastx``` script using ```xargs```. As before, this process can be parellelized using the (```-P [# cores]```) flag.  

###### Assembly
+ Perform assembly for each of the read files extracted from mapping files
```shell
ls *.fq | cut -f1 -d'.' | xargs -n1 -I{} spades.py -s {}.fq -o {} -t 3
```
This would perform an assembly with SPAdes for each of the fastq files present in the directory.

###### Taxonomy of microbe contigs
+ Combine all contig files, blast all against local copy of the NCBI nt database:
```shell
  blastn -task megablast -query all_contigs.fas -db ~/ncbi_databases/nt/nt -evalue 1e-12 -culling_limit 5 -num_threads 3 -out all_contigs.blast -outfmt '6 qseqid staxids bitscore std sscinames sskingdoms stitle length pident evalue'
```
+ Create taxonomy table from blast results
```shell
blobtools create -i all_contigs.fas -y spades -t all_contigs.blast --nodes nodes.dmp --names names.dmp
blobtools view -i BlobDB.json -r all > hits.txt
```
Blobtools can be used for other interesting summaries and graphs, so it is worthwhile to check out the manual.  


###### Potential next steps
+ Hits of interest, perform *de-novo* meta assembly of corresponding sequencing libraries with MEGAHIT.
+ Use [anvi'o](https://peerj.com/articles/1319/) to get an overview of the taxonomic composition of you meta-assembly
+ Retrieve draft assembly of your target microbe by
  + Taxonomic assignment of all contigs with BLAST & blobtools (&/or anvi'o)
  + Mapping all reads to contigs identified as target microbe
  + Extracting corresponding microbe reads
  + Refined microbe assembly with SPAdes
  + Repeat previous 4 steps if necessary   
