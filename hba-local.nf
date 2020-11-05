hbaSequences = Channel.fromPath("hba1.fasta.gz")

process alignMultipleSequences {
    input: file sequences from hbaSequences
    output: file "hba-alignment.fasta.gz" into hbaAlignment

    """
    gunzip --to-stdout $sequences | mafft --auto - > hba-alignment.fasta
    gzip hba-alignment.fasta
    """
}

process buildTree {
    publishDir "./"

    input: file alignment from hbaAlignment
    output: file "hba-tree" into hbaTree

    """
    gunzip --to-stdout $alignment | FastTree > hba-tree
    """
}