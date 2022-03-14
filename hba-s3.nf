hbaSequences = Channel.fromPath("s3://bl5632/hba1.fasta.gz")

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
    publishDir "s3://bl5632"

    input: file alignment from hbaAlignment
    output: file "hba-tree" into hbaTree

    """
    gunzip --to-stdout $alignment | FastTree > hba-tree
    """
}
