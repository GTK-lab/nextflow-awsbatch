# Nextflow with AWS Batch: A Worked Example

1. [Introduction](#introduction)
2. [Using Nextflow Locally](#using-nextflow-locally)
    1. [Channels](#channels)
    2. [Processes](#processes)
    3. [workDir and publishDir](#workdir-and-publishdir)
3. [Using Nextflow with Docker Containers](#using-nextflow-with-docker-containers)
4. [Using Nextflow with AWS S3](#using-nextflow-with-aws-s3)
5. [Using Nextflow with AWS Batch](#using-nextflow-with-aws-batch)
    1. [Configurations for AWS](#configurations-for-aws)
    2. [Specifying a S3 bucket as work directory](#specifying-a-s3-bucket-as-work-directory)
6. [A larger example: SARS-CoV-2 in Singapore](#a-larger-example-sars-cov-2-in-singapore)

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
Visualise this tree with any tree visualiser to make sure it's working (we used [iroki.net](https://www.iroki.net/))!

<div align="center">
<img src="hba-tree.png">
</div>

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

Lastly, run nextflow with the `-profile docker` argument (that's `-profile` with a single-dash, not `--profile`!)

```groovy
nextflow run hba-docker.nf -profile docker
```

Without the `-profile docker` argument, Nextflow will not use the docker containers.
This allows one to alternate between "direct" local and containerised execution environments by changing command line arguments only.

## Using Nextflow with AWS S3

If you're working with AWS, you might have or may want to store your files on S3.
Nextflow supports using and publishing to S3: simply use the `s3` protocol in your file paths:

```groovy
hbaSequences = Channel.fromPath("s3://nextflow-awsbatch/hba1.fasta.gz")
// ...

process buildTree {
    container "biocontainers/fasttree:v2.1.10-2-deb_cv1"
    publishDir "s3://nextflow-awsbatch/"

    // ...
}
```

Using S3, you should have a Nextflow script that looks like [hba-s3.nf](./hba-s3.nf).

## Using Nextflow with AWS Batch

For Nextflow to use AWS Batch, you must first
(i) specify publicly available Docker containers for some of your processes,
(ii) set-up a compute environment (possibly with a custom AMI) and job queue on AWS,
(ii) configure AWS in the configuration file, and
(iii) specify a S3 bucket to use as working directory for intermediate files.

The (i) use of Docker containers has already been covered in ["Using Nextflow with Docker Containers"](#using-nextflow-with-docker-containers), and we will skip (ii) setting up AWS as well in order to focus on Nextflow.

### Configurations for AWS

Just as with docker, we will create a new profile `awsbatch` in our configuration file to provide Nextflow with the information it needs to use AWS Batch.
Minimally, you will only need to set four variables:

```groovy
profiles {
    docker {
        docker.enabled = true
    }

    // Set up a new awsbatch profile
    awsbatch {
        process.executor = 'awsbatch'
        process.queue = 'nextflow-awsbatch-queue-2'
        aws.region = 'ap-southeast-1'
        aws.batch.cliPath = '/home/ec2-user/miniconda/bin/aws'
    }
}
```

Make sure to replace `process.queue` with the name of your job queue in AWS Batch, `aws.region` with the AWS region you are operating on, and `aws.batch.cliPath` with the file path to the AWS CLI binary on the AMI you have configured for your compute environment.
If you are certain that the AMI you are using will have the AWS CLI in its `$PATH`, then it is okay to omit the `aws.batch.cliPath` line.

### Specifying a S3 bucket as work directory.

Note that this work directory is *not* the same as the ["Using Nextflow with AWS S3"](#using-nextflow-with-aws-s3) — that previous section only specified S3 as the input and output directories.
Here, we are providing a bucket for Nextflow to store intermediate files.
This is accomplished by means of an additional command-line flag `-work-dir` (or equivalently, `-bucket-dir`).

```
nextflow run hba-s3.nf -profile awsbatch -work-dir s3://nextflow-awsbatch/temp
```

Take note of how the new profile is being used: `-profile awsbatch`.

## A larger example: SARS-CoV-2 in Singapore

Now, let's try to scale our analysis up from three HBA sequences to a thousand SARS-CoV-2 viral genomes.
First, download a collection of SARS-CoV-2 genomes from the [GISAID database](https://www.gisaid.org/) (registration required), filtering by location to "Asia/Singapore" (or your region of choice).
Next, upload the gzipped FASTA file of the downloaded genomes onto AWS S3.

Now, all we have to do is to replace the input channel path with the newly uploaded SARS-CoV-2 genomes:

```groovy
covidSequences = Channel.fromPath("s3://nextflow-awsbatch/sars-cov2-singapore.fasta.gz")

// ...also change the variable names so that they are self-documenting!
```

and the `alignMultipleSequences` process is good to go!
However the `buildTree` process might fail as a result of running out of memory, so we will also increase the memory allocated to that process using the `memory` directive:

```groovy
process buildTree {
    container "biocontainers/fasttree:v2.1.10-2-deb_cv1"
    publishDir "s3://nextflow-awsbatch/"
    memory "16 GB"

    // ...
```

Given the large number of sequences involved, this process can take about 4-5 hours to run from start to finish. Once completed, visualize your tree using the phylogenetic tree viewer of your choice!

<div align="center">
<img src="covid-tree.png">
</div>
