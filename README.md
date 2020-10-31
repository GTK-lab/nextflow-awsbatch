# Nextflow with AWS Batch: A Worked Example

1. [Introduction](#introduction)
2. [Using Nextflow Locally](#using-nextflow-locally)
    1. [Channels](#channels)
    2. [Processes](#processes)
    3. [workDir and publishDir](#workdir-and-publishdir)
3. [Using Nextflow with Docker Containers](#using-nextflow-with-docker-containers)
4. [Using Nextflow with AWS S3](#using-nextflow-with-aws-s3)
5. [Using Nextflow with AWS Batch](#using-nextflow-with-aws-batch)
6. [A larger example: COVID-19 in Singapore](#a-larger-example-covid-19-in-singapore)

## Introduction

[*Nextflow*](https://www.nextflow.io/) is a workflow management system in the vein of Snakemake or even GNU Make.
Nextflow makes containerisation and configuration for cloud computing easy, allowing for reproducible and scalable computational analysis.

In this post, we provide a worked example of Nextflow in the construction of a phylogenetic tree.
To do so, we use [MAFFT](https://mafft.cbrc.jp/alignment/software/) for multiple sequence alignment, and [FastTree](http://www.microbesonline.org/fasttree/) for tree construction.

## Using Nextflow Locally

In this first section, we will construct a small phylogenetic tree based on orthologs of the human haemogoblin alpha 1 subunit.
Three sequences are provided in the FASTA file at [hba1.fasta.gz](./hba1.fasta.gz):

- Human, HBA1 or [ENSG00000206172](https://asia.ensembl.org/Homo_sapiens/Gene/Summary?db=core;g=ENSG00000206172;r=16:176680-177522).
- Mouse, Hba-a1 or [ENSMUSG00000069919](https://asia.ensembl.org/Mus_musculus/Gene/Summary?g=ENSMUSG00000069919;r=11:32283511-32284465).
- Zebrafish, zgc:163057 or [ENSDARG00000045144](https://asia.ensembl.org/Danio_rerio/Gene/Summary?g=ENSDARG00000045144;r=12:20336070-20337274;t=ENSDART00000066385).

### Channels

[*Channels*](https://www.nextflow.io/docs/latest/channel.html) are sources of data.
They are useful for holding input or intermediate files.
For example, to store our sequences from the aforementioned [hba1.fasta.gz](./hba1.fasta.gz) into a channel, we can use the `fromPath` method to create a channel named `hbaSequences` containing that single FASTA file.
Create a file named `hba1-local.nf`, and write:

```groovy
hbaSequences = Channel.fromPath("hba1.fasta.gz")
```

To execute this nextflow script, simply use the nextflow subcommand `run`:

```
nextflow run hba1-local.nf
```

Nothing will happen just yet, but that's to be expected: We've declared our data, but we haven't yet defined what should be done to that data!

### Processes

[*Processes*](https://www.nextflow.io/docs/latest/process.html) can act on data from channels.
Processes start with the `process` keyword, followed by a name, then a block body.
The data which the process acts on is specified by the `input` keyword, and `output` declares the data output by the process.
At the end of the block body is the `script` which is to be executed.

For example, a process to align the sequences from our just-created `hbaSequences` can be written like:

```groovy
process {
    input: file sequences from hbaSequences
    output: file "hba-alignment.fasta.gz" into hbaAlignment

    """
    gunzip --to-stdout $sequences | mafft --auto - > hba-alignment.fasta
    gzip hba-alignment.fasta
    """"
}
```

Note that the output implicitly creates a new channel named `hbaAlignment` which contains the single file `hba-alignment.fasta.gz` output by the script.
This new channel can then be used in a subsequent tree construction process:

```groovy
process buildTree {
    input: file alignment from hbaAlignment
    output: file "hba-tree" into hbaTree

    """
    gunzip --to-stdout $alignment | FastTree > hba-tree
    """
}
```

### workDir and publishDir

By default, processes create their output files in the Nextflow-managed `workDir`, which is usually a directory named `work` in the current working directory.
In order to place process output files elsewhere, you will need to specify the `publishDir` using the `publishDir` directive.

So, if we want to place the tree file produced by the `buildTree` process in the current working directory, we can rewrite it as:

```groovy
process buildTree {
    publishDir './'

    input: file alignment from hbaAlignment
    output: file "hba-tree" into hbaTree

    """
    gunzip --to-stdout $alignment | FastTree > hba-tree
    """
}
```

In the end, you should end up with a file like [hba-local.nf](./hba-local.nf).
Now, if we execute the script with `nextflow run hba-local.nf`, there should be an output file `hba-tree` produced in the current working directory.

## Using Nextflow with Docker Containers

Next, let's try to containerise each of our two processes.
This can be done in three steps.

First, specify the docker containers to be used for each process in the nextflow script file, using the `container` directive.

```groovy
process alignMultipleSequences {
    container "biocontainers/mafft:v7.407-2-deb_cv1"

    // ...
}

process buildTree {
    container "biocontainers/fasttree:v2.1.10-2-deb_cv1"
    publishDir './'

    // ...
}
```

This should result in a modified nextflow script which looks like [hba-docker.nf](./hba-docker.nf).

Secondly, we need to specify a *profile* via a [configuration file](https://www.nextflow.io/docs/latest/config.html).
Create a new file `nextflow.config`, and define a new profile `docker` which sets the `enabled` property of the `docker` scope to `true`.

```groovy
profiles {
    docker {
        docker.enabled = true
    }
}
```

Lastly, run nextflow with the `-profile docker` argument.
That's `-profile` with a single dash, not `--profile` --- Nextflow silently ignores unrecognised command line arguments, so make sure you type this one correctly!

```groovy
nextflow run hba-docker.nf -profile docker
```

Without the `-profile docker` argument, Nextflow will not use the docker containers.
This allows one to alternate between "direct" local and containerised execution environments by changing command line arguments only.

## Using Nextflow with AWS S3

This is as simple as adding the `s3` protocol to the input file path:

```groovy
hbaSequences = Channel.fromPath("s3://nextflow-awsbatch/hba1.fasta.gz")
```

And doing the same for the publish directory `publishDir`:

```groovy
process buildTree {
    container "biocontainers/fasttree:v2.1.10-2-deb_cv1"
    publishDir "s3://nextflow-awsbatch/"

    //...
}
```

You should have a Nextflow script that looks like [hba-s3.nf](./hba-s3.nf).

### Using Nextflow with AWS Batch

### A larger example: COVID-19 in Singapore

### Changes

- 28 Oct 2020 - Marcus
  - Addition of `awsbatch` profile to the configuration file
