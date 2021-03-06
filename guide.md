# Guide to replicate data retrieval and analyses from [Gerth & Hurst 2017](http://dx.doi.org/10.7717/peerj.3529)

This guide lists the steps we used to screen short read sequencing data from honey bees (*Apis* ssp.) for genomic data of their associated microbes. In general, this is also transferable to retrieving symbiont data from other Eukaryote sequencing projects. All intermediate files mentioned can be accessed via https://github.com/gerthmicha/symbiont-sra. The following tools were used (alternatives in brackets):

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

## Workflow
The following description explains how we extracted symbiont data from *Apis* DNA reads, but the general precedure was identical for screening RNA data. All files mentioned here can be found in the '[example](https://github.com/gerthmicha/symbiont-sra/tree/master/example)' folder. All of the steps listed here assume a directory layout as follows:
+ working_directory
  + reads (this is where the downloaded reads are stored)
  + mapping (this is where the mapping results are written)
  + mapped_reads (this is where the reads extracted from the mapping files are stored)
  + mapped_reads_assembled (this is where SPades assembly folders are created)

The following files should be in working_directory (all can be found in the [example](https://github.com/gerthmicha/symbiont-sra/tree/master/example) folder):
+ [sra_accession_list_dna.txt](https://github.com/gerthmicha/symbiont-sra/blob/master/example/sra_accession_list_dna.txt) (list of SRA experiments to analyse)
+ [reference_path_symb.fas](https://github.com/gerthmicha/symbiont-sra/blob/master/example/reference_path_symb.fas) (reference sequences from taxa which will be targeted in the screen)

This directory layout is mostly for orientation in following this guide and not essential for the analyses as such.

#### Compile list of SRA experiments
+ Search NCBI's short read archive <http://www.ncbi.nlm.nih.gov/sra> for experiments of interest and download summary files. E.g., WGS studies from *Apis*, targeting DNA.
+ Retrieve run accession numbers associated with each experiment from this file.

#### Download of short read files
+ Using ```fastq-dump``` from NCBI's SRA tools , download all reads and convert from sra format into zipped fastq files. This can be parallelized, e.g., with ```xargs -P [# cores]```:
```shell
cat sra_accession_list.txt | xargs -n 1 -P 6 -I{} fastq-dump -O reads --gzip --split-3 {}
```
Alternatively, access NCBI's or ENA's ftp servers via wget directly, which is much faster. Please see tutorials here on how to do this: <https://www.ncbi.nlm.nih.gov/books/NBK158899/>
& here: 
<http://www.ebi.ac.uk/ena/browse/read-download>

_UPDATE_:
I wrote a [script](https://github.com/gerthmicha/symbiont-sra/tree/master/sra_download.pl) that automates the download of fastq files from the European Nuleaotide archive. This should be much faster than using sra-tools. 


#### Compile reference sequences
+ For each symbiont/microbe to be searched for, include a single signature sequence into a fasta file (e.g., bacterial 16S, here: [reference_path_symb.fas](https://github.com/gerthmicha/symbiont-sra/blob/master/example/reference_path_symb.fas) – all other references can be found in the [references](https://github.com/gerthmicha/symbiont-sra/tree/master/references) folder).

#### Mapping
+ Map all downloaded reads to reference sequences.
+ Paired-end mapping of all read files stored in the current folder to the reference fasta file:
```shell
ls *_* | cut -f1 -d'_' | sort -u | xargs -I{} -n 1 ngm --bam --no-unal -1 {}_1.fastq.gz -2 {}_2.fastq.gz -r ../apis_symbiont_reference.fas -o ../mapping/{}.bam -g -t 6 -i 0.95
```
+ Single-end mapping:
```shell
ls *.fastq | cut -d'.' -f1 | sort -u | xargs -I{} -n 1 ngm --bam --no-unal -q {}.fastq.gz -r ../apis_symbiont_reference.fas -o ../mapping/{}.bam -g -t 6 -i 0.95
```
In these examples, all mapping files in bam format are stored in the folder 'mapping'. Minimum identity of mapped reads to reference can be controlled with ```-i``` in NextGenMap (here: ```-i 0.95```=95%). In order to save disc space, only aligned reads are stored in the bam files (```--no-unal```).

#### Retreive mapping results
+ Sort all bam files in current folder, count number of mapped reads, write results to file:
```shell
for i in *.bam; do samtools sort ${i} > $(basename ${i} .bam).sort.bam; done
for i in *.sort.bam; do samtools view -c ${i} >> mapping_count.txt; done
ls *.sort.bam >> names.txt
paste names.txt mapping_count.txt >> mapping_results.txt
```
In this example, all bam files are sorted with a for loop (the unsorted bam files can be discarded afterwards in order to save disk space). Next, another loop will count the mapped reads in each of the bam files. Finally, counts will be written with the names of the corresponding bam files into a new file.

#### Extract microbe reads from mapping files
+ Extract reads from bam files for mappings in which at least 1000 reads were mapped:
```shell
awk '$2 > 999' mapping_results.txt | cut -f1 | cut -f1 -d'.' | xargs -n 1 -P 3 -I{} bam2fastx -Q -q -A -o ../mapped_reads/{}.fq {}.bam
```
Here, the names of the bam files with more 1000 or more mapped reads will be extracted using ```awk```. The names are then piped to the ```bam2fastx``` script using ```xargs```. As before, this process can be parellelized using the (```-P [# cores]```) flag.  

#### Assembly
+ Perform assembly for each of the read files extracted from mapping files
```shell
ls *.fq | cut -f1 -d'.' | xargs -n1 -I{} spades.py -s {}.fq -o ../mapped_reads_assembled/{} -t 6
```
This would perform an assembly with SPAdes for each of the fastq files present in the directory.

#### Taxonomy of microbe contigs
+ Rename contigs in all assembly files before concatenating all
```shell
  ls | xargs -I{} sed -i 's/NODE/{}/' {}/scaffolds.fasta
  cat */scaffolds.fasta > all_contigs.fas
```
This assumes there is a single directory per assembly in the current directory.
+ Blast all against local copy of the NCBI nt database
```shell
  blastn -task megablast -query all_contigs.fas -db nt -evalue 1e-12 -culling_limit 5 -num_threads 3 -out all_contigs.blast -outfmt '6 qseqid staxids bitscore std stitle'
```
+ Create taxonomy table from blast results
```shell
blobtools create -i all_contigs.fas -y spades -t all_contigs.blast --nodes nodes.dmp --names names.dmp
blobtools view -i BlobDB.json -r all
```
Blobtools can be used for other interesting summaries and graphs, so it is worthwhile to check out the manual.  


## Potential next steps
+ Hits of interest, perform *de-novo* meta assembly of corresponding sequencing libraries with MEGAHIT.
+ Use [anvi'o](https://peerj.com/articles/1319/) to get an overview of the taxonomic composition of you meta-assembly
+ Retrieve draft assembly of your target microbe by
  + Taxonomic assignment of all contigs with BLAST & blobtools (&/or anvi'o)
  + Mapping all reads to contigs identified as target microbe
  + Extracting corresponding microbe reads
  + Refined microbe assembly with SPAdes
  + Repeat previous 4 steps if necessary   
