#! /usr/bin/env nextflow

// hbaSequences = Channel.fromPath("s3://nextflow-awsbatch/hba1.fasta.gz")
hbaSequences = Channel.fromPath("s3://nextflow-awsbatch/sars-cov2-singapore.fasta.gz")

process alignMultipleSequences {
    container "biocontainers/mafft:v7.407-2-deb_cv1"

    input: file sequences from hbaSequences
    output: file "hba-alignment.fasta.gz" into hbaAlignment

    """
    gunzip --to-stdout $sequences | mafft --auto - > hba-alignment.fasta
    gzip hba-alignment.fasta
    """
}

process buildTree {
    container "biocontainers/fasttree:v2.1.10-2-deb_cv1"
    publishDir "s3://nextflow-awsbatch/"

    input: file alignment from hbaAlignment
    output: file "hba-tree" into hbaTree

    """
    gunzip --to-stdout $alignment | FastTree > hba-tree
    """
}
