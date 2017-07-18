#!/usr/bin/perl
use strict;
# This script automates the download of fastq files from the European Nucleotide Archive. Uses regular NCBI SRA accession numbers as input.
# Download instructions are from http://www.ebi.ac.uk/ena/browse/read-download 

# define input files
my $srafile = $ARGV[0];
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
my $ymd = sprintf("%04d%02d%02d%02d%02d",$year+1900,$mon+1,$mday,$hour,$min);
my $filename = $ymd."_wget.log";
if(!defined $ARGV[0]){
        print "This script will download fastq files from the European Nucleotide Archive database. Requires input file with a single SRA accession number per line (accession numbers are identical to NCBI's SRA accession numbers). Please note that this will access European servers, and thus probably be most efficient when used in Europe. Please also note that this script will sort the file with accession numbers, if an unsorted one was provided. \n\nUSAGE:\tperl sra_dowload.pl [sra file]\n";
        }
else{
# Check if input files were provided, else show usage information       
	system "sort -o $srafile $srafile";
	open (SRA , '<' , $srafile) or die "\n>FILE MISSING<\n\nplease specify path to SRA file (one accession number per line)!\n\n";
	my $count = 0;
	while( <SRA> ) { $count++; }
	printf("\n[%02d:%02d:%02d]", $hour, $min, $sec);
	print "\tFile apparently contains $count accession numbers. Writing log file to $filename!";
	close(SRA);
	open (SRA , '<' , $srafile);
	my $libcount = 0;
	my $line;
	my $currentlib;
	while ($line = <SRA>) {
	# process each accession number separately
        	chomp $line;
		#count processed lines
                $libcount++;
		# Print date & time (here & in front of any output)
		printf("\n[%02d:%02d:%02d]", $hour, $min, $sec);
		# Print current library name
		print "\tDownloading library $line\.\n";
		# Check if SRA accesion numbers have the right length. If not, print error message and move to next entry. 
		if(length($line)<9 or length($line)>12){
			printf("\n[%02d:%02d:%02d]", $hour, $min, $sec);
			print "\tWARNING! $line does not appear to be a valid SRA accesion number. Please check!";
		}
		# When valid SRA accession number is provided, call wget and download library. 
		# Definitions for folders in which fastq files are stored can be found under http://www.ebi.ac.uk/ena/browse/read-download  
		if(length($line)==12){
			system "wget --retry-connrefused -q -a $filename --show-progress 'ftp://ftp.sra.ebi.ac.uk/vol1/fastq/".substr($line,0,6).substr($line,9,3)."/".$line."/*'";
		}	
		if(length($line)==11){
                       	system "wget --retry-connrefused -q --show-progress 'ftp://ftp.sra.ebi.ac.uk/vol1/fastq/".substr($line,0,6)."/0".substr($line,9,2)."/".$line."/*'";
		}	
		if(length($line)==10){
			system "wget --retry-connrefused -q --show-progress 'ftp://ftp.sra.ebi.ac.uk/vol1/fastq/".substr($line,0,6)."/00".substr($line,9,1)."/".$line."/*'";
		}		
		if(length($line)==9){
			system "wget -a $filename --retry-connrefused -q --show-progress -R '*.listing' 'ftp://ftp.sra.ebi.ac.uk/vol1/fastq/".substr($line,0,6)."/".$line."/*'";
		}
		$currentlib = $count-$libcount;
		# Print info on how many libraries were downloaded and how many remain
                printf("\n[%02d:%02d:%02d]", $hour, $min, $sec);
                print "\tRemaining donwloads: $currentlib of $count libraries." ;
	
		}
	close(SRA);
	printf("\n[%02d:%02d:%02d]", $hour, $min, $sec);
	print "\tDownloaded $count libraries. Performing checks.\n";
	# Check if for every accession number in file, at least 1 fastq file was downloaded. 
	# If not, print warning. (Could use more sophisticated check?)	
	my $missing= `ls *fastq* | cut -f1 -d'.' | cut -f1 -d'_' | sort -u | comm -13 - $srafile | sed "s/ //g"`;	
	if($missing  ne ''){
		printf("\n[%02d:%02d:%02d]", $hour, $min, $sec);
		print("\tWARNING! The follwing SRA accessions were not downloaded. Please check log file!\n\n$missing\n");
		
	}
	else{
		printf("\n[%02d:%02d:%02d]", $hour, $min, $sec);
		print("\tAll done!\n");	
	}	
}


