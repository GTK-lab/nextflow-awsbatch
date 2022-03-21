covidSequences = Channel.fromPath("s3://bl5632/data/sars-cov2-singapore.fasta.gz")

process alignMultipleSequences {
    container "biocontainers/mafft:v7.407-2-deb_cv1"

    input: file sequences from covidSequences
    output: file "covid-alignment.fasta.gz" into covidAlignment

    """
    gunzip --to-stdout $sequences | mafft --auto - > covid-alignment.fasta
    gzip covid-alignment.fasta
    """
}

process buildTree {
    container "biocontainers/fasttree:v2.1.10-2-deb_cv1"
    publishDir "s3://bl5632/MY-NAME"
    memory "16 GB"


    input: file alignment from covidAlignment
    output: file "covid-tree" into covidTree

    """
    gunzip --to-stdout $alignment | FastTree > covid-tree
    """
}
