# Multi-Multi-FASTA/Q file format

DNA and protein sequences are often stored in FASTA format [1-4].
These days we put multiple sequences in a FASTA file,
but originally FASTA file was supposed to contain just a single sequence.
A file with multiple sequences was called "Multi-FASTA".

Now, what if you want to combine not only multiple sequences, but multiple FASTA files into a single file?
You could use tar, but the resulting .tar file is binary and not compatible with FASTA-processing tools.
Simply concatenating the individual files together would lose the file names.

Hence, this proposal of Multi-Multi-FASTA file format.
It's a FASTA file, where sequence headers can have an optional ">filename" suffix.
So, the complete sequence header looks like ">sequence name>filename".
Such header indicates that this, and all subsequent sequences belong to the file "filename".
This allows deconstructing a Multi-Multi-FASTA file back to individual FASTA files.

Importantly, Multi-Multi-FASTA file can be processed with FASTA-compatible tools.
It can be compressed with FASTA-specific compressors, searched with homology search tools, etc.
When necessary, it can be deconstructed back into original FASTA files.

The same principle can be used to combine multiple FASTQ files into a single Multi-Multi-FASTQ file.
For FASTQ data, "@" is the default separator, so the tagged name looks like: "@readname@filename".



## Implementation

The script _mumu.pl_ at this repo is the reference implementation.
It allows both packing and unpacking a Multi-Multi-FASTA/Q file.

### Installing

Prerequisites: git (for downloading), perl.
E.g., to install on Ubuntu: `sudo apt install git perl`.
On Mac OS you may have to install Xcode Command Line Tools.

Downloading and installing:
```
git clone https://github.com/KirillKryukov/mumu.git
sudo cp mumu/mumu.pl /usr/local/bin/
```

Or just place the _mumu.pl_ script where you need it.

### Packing multiple files into a Multi-Multi-FASTA/Q file

`mumu.pl 'data/*.fa' >all.mfa` - Combine all .fa files in "data" directory, store the result in a file "all.mfa".

`mumu.pl --dir data '*.fa' >all.mfa` - Same, but enters into the "data" directory first. Filenames stored in the output will have no directory part.

`mumu.pl --dir data --sep '<' '*.fa' >all.mfa` - Use '<' as a separator between sequence name and filename in the output.

`mumu.pl --dir data --all '*.fa' >all.mfa` - Add filename to all sequence names.
By default only the first sequence of each file is tagged with filename.

`mumu.pl --stdin <list.txt >all.mfa` - Pack files listed in "list.txt" into "all.mfa".

`mumu.pl --fastq --dir reads '*.fq' >all.mfq` - Combine FASTQ files into a single Multi-Multi-FASTQ file.

`mumu.pl '*.fa' >all.fa` - Don't do this! "all.fa" will be counted as one of the input files, potentially overflowing your storage space.

`mumu.pl --dir data --no-ext --cmd "unnaf '{PATH}'" '*.naf' >all.mfa` - Decompress NAF-formatted files and pack their data into "all.mfa".

### Unpacking a Multi-Multi-FASTA/Q file

`mumu.pl --unpack all.mfa` - Unpacks "all.mfa" into individual files.

`mumu.pl --unpack --dir 'new' all.mfa` - Creates directory "new", enters it, and then unpacks "all.mfa".

`mumu.pl --unpack --sep '<' all.mfa` - Unpacks file where "<" was used as separator between sequence name and filename.

`mumu.pl --unpack --dir 'new' all.mfa --cmd "ennaf -22 -o '{PATH}.naf'"` - Unpack "all.mfa", compress each unpacked file with _ennaf_ on the fly.



## FAQ

**Why not put the filename first, like ">filename>sequence name" ?**<br>
The reason is that in many cases sequence names begin with accession number.
Putting filename in the end keeps compatibility with software tools that read only accession number and ignore the rest of the name.

**Is it OK to repeat the ">" in sequence name?**<br>
By default, sequence name and filename are separated by the ">" character,
for the reason that this character not normally found in sequence names.
However, some tools may possibly have problem with a second ">" in one line.
In such cases, it's possible to use another character, using `--sep '?'` option.
Naturally, when using a custom separator, it has to be specified in both packing and unpacking steps.

Note that the separator does not have to be a single character.
You can use any string,
as long as the unpacking side knows it and can supply it to the unpacking command.

**Should all sequences be tagged with filenames, or only first sequence of each file?**<br>
This depends on the usage scenario.
If the workflow involves re-ordering or filtering of sequences, then tagging each sequence may be necessary.
On the other hand, if all sequences will be retained, then tagging only first sequence per file is more compact.
The format and implementation support both cases.

**What if the FASTA files to be combined are located in multiple directories?**<br>
No problem, the filename part of the Multi-Multi-FASTA file can include path to the file,
like this: ">sequence name>full/path/to/file".
Whatever file paths are supplied to the packing command will be recorded in the packed file.
During unpacking, the directories will be created automatically.

**What filename extension should be used for Multi-Multi-FASTA/Q files?**<br>
Extensions ".mfa" and ".mfq" can be used for Multi-Multi-FASTA and Multi-Multi-FASTQ files, respectively.
Alternatively, any of the usual FASTA and FASTQ extensions can be used (".fa", ".fasta", ".fna", ".fq", ".fastq", etc).

**Should I compress \*.fa or '\*.fa'?**<br>
The recommended and more robust way is to use quotation: **'\*.fa'**.
Trying to merge \*.fa results in shell expanding the mask and supplying all filenames as arguments to the _mumu.pl_ script.
Normally it may work fine, but some day you'll try to compress a directory with thousands of files,
which may overflow the maximum argv size of your system.
When quoting the mask ('*.fa'), mask expansion occurs within the _mumu.pl_ script,
where the limit is determined by available RAM, and therefore much larger number of files can be processed safely.

**What about preserving permissions, owner and timestamp of the packed files?**<br>
Currently these are not supported, but in principle the format can be extended to accomodate this information,
if there is sufficient interest in this.

**Can it pack a directory of FASTA files recursively?**<br>
The format has no problem with storing the entire directory tree.
The current tool does not have recursive mode,
but it can read the list of files to compress from stdin, making recursive packing possible.
For example, here is how you can pack an entire directory using _find_ command:<br>
`find DATASET -type f -name '*.fna' | mumu.pl --stdin | ennaf -22 -o DATASET.mfa.naf`

**Does it overwrite existing files during unpacking?**<br>
By default, no. Add `--overwrite` option to overwrite existing files.

**Can a malicious archive put files outside of target directory during unpacking?**<br>
No. All absolute paths are converted to relative, and all '..' in paths are ignored during unpacking.
It can only go down the directory tree, not up.

**Can gzipped files be decompressed on-the-fly and extracted data packed together?**<br>
Yes. `--cmd ...` option allows specifying a command that will be run on every processed individual file (during both packing and unpacking).
This allows decompressing the files on-the-fly before packing their data.
It also allows compressing (or otherwise processing) each extracted file during unpacking.



## Compressing related genomes

Suppose we have a set of related genomes, for example, 1,697 genomes of <i>Helicobacter pylori</i>.
Uncompressed they occupy 2.8 GB in FASTA format.
Compressed one by one using gzip results in a 804 MB set of files.
A better compressor, such as [naf](https://github.com/KirillKryukov/naf), brings the size down to 675 MB.
However, the genomes still remain in 1,697 separate files.

Let's try the two most common ways of bundling the files together - zip and tar.gz:
we obtain archives of 767 and 803 MB, respectively.
Although we now have single file, convenient for sharing or moving around, the size is still large.
Also, accessing the sequence data now requires de-constructing the archive back into individual files.

A stronger compressor may be able to compress the tar file into a smaller archive.
But the necessity to restore the original files before working on them will remain.

Now, what if we combine the genomes into a Multi-Multi-FASTA file,
and then compress with [naf](https://github.com/KirillKryukov/naf)?
We obtain a file that is only **80 MB** - 10 times smaller and easy to send over network.

Importantly, FASTA-formatted sequences contained in this archive
can be accessed by simply decompressing and piping the data to a FASTA-compatible tool.
This means that many analyses can be performed without unpacking the archive, and without storing 1,697 files on filesystem.
Only when necessary we will de-construct the archive into individual FASTA files.

**Commands:**

Compressing:<br>
`mumu.pl --dir 'Helicobacter' 'Helicobacter pylori*' | ennaf -22 --text -o 'Hp.mfa.naf'`

Decompressing and unpacking:<br>
`unnaf 'Hp.mfa.naf' | mumu.pl --unpack --dir 'Helicobacter'`



## Compressing already compressed files

Suppose you have a set of genomes which are already compressed one by one (e.g., using NAF format).
Now you'd like to pack them together and compress them into a single file.
The simplest way is to decompress the genomes first, but then you'd have to store all the huge decompressed data.
Ideally you would prefer decompression to occur on-the-fly when packing the sequences together.
Using the `--cmd` option this can be achieved in a single step:

`mumu.pl --dir 'Helicobacter' --no-ext --cmd "unnaf '{PATH}'" 'Helicobacter pylori*.naf' | ennaf -22 --text -o 'Hp.mfa.naf'`

It is also possible to unpack the resulting archive back directly into individually compressed genomes:

`unnaf 'Hp.mfa.naf' | mumu.pl --unpack --dir 'Helicobacter' --cmd "ennaf -22 -o '{PATH}.naf'"`



## References

  1. David J. Lipman, William R. Pearson (1985) <b>"Rapid and sensitive protein similarity searches"</b> <i>Science</i>, 22 March 1985, 227(4693), 1435-1441.

  2. William R. Pearson, David J. Lipman (1988) <b>"Improved tools for biological sequence comparison"</b>
<i>Proc. Natl. Acad. Sci. USA</i>, April 1988, 85(8), 2444-2448.

  3. Hongen Zhang (2016) <b>"Overview of sequence data formats"</b> <i>Methods in Molecular Biology</i>, 1 January 2016, 1418, 3-17.

  4. <b>"FASTA Format"</b> at Wikipedia: https://en.wikipedia.org/wiki/FASTA_format



## Related papers and links

  * Peter J.A. Cock, Christopher J. Fields, Naohisa Goto, Michael L. Heuer, Peter M. Rice (2010)
<b>"The sanger FASTQ file format for sequences with quality scores, and the Solexa/Illumina FASTQ variants"</b>
<i>Nucleic Acids Res.</i>, April 2010, 38, 1767-1771.

  * Kirill Kryukov, Mahoko Takahashi Ueda, So Nakagawa, Tadashi Imanishi (2019)
<b>"Nucleotide Archival Format (NAF) enables efficient lossless reference-free compression of DNA sequences"</b>
<i>Bioinformatics</i>, 35(19), 3826-3828.

  * Kirill Kryukov, Mahoko Takahashi Ueda, So Nakagawa, Tadashi Imanishi (2020)
<b>"Sequence Compression Benchmark (SCB) database - A comprehensive evaluation of reference-free compressors for FASTA-formatted sequences"</b>
<i>GigaScience</i>, 9(7), giaa072.

  * Tim Hulsen, Saumya S. Jamuar, Alan R. Moody, Jason H. Karnes, Orsolya Varga, Stine Hedensted, Roberto Spreafico, David A. Hafler, Eoin F. McKinney (2019)
<b>"From Big Data to Precision Medicine"</b>
<i>Frontiers in Medicine</i>, 1 March 2019, 6, 34.

  * Heng Li, <b>"Seqtk"</b>: https://github.com/lh3/seqtk

  * Wei Shen, Shuai Le, Yan Li, Fuquan Hu (2016) <b>"SeqKit: A Cross-Platform and Ultrafast Toolkit for FASTA/Q File Manipulation"</b>
<i>PLoS One</i>, 5 October 2016, 11(10), e0163962.

  * <b>"FASTX-Toolkit"</b>: http://hannonlab.cshl.edu/fastx_toolkit/

  * <b>"Seqmagick"</b>: https://fhcrc.github.io/seqmagick/

  * <b>"Fasta Utilities"</b>: https://github.com/jimhester/fasta_utilities

  * Ola Spjuth, Erik Bongcam-Rudloff, Johan Dahlberg, Martin Dahlo, Aleksi Kallio, Luca Pireddu, Francesco Vezzi, Eija Korpelainen (2016)
<b>"Recommendations on e-infrastructures for next-generation sequencing"</b> <i>GigaScience</i>, 2016, 5, 26.

  * Morteza Hosseini, Diogo Pratas, Armando J. Pinho (2016)
<b>"A Survey on Data Compression Methods for Biological Sequences"</b>
<i>Information</i>, 14 October 2016, 7, 56.

  * Mikel Hernaez, Dmitri Pavlichin, Tsachy Weissman, Idoia Ochoa (2019)
<b>"Genomic Data Compression"</b> <i>Annu. Rev. Biomed. Data Sci.</i> 2019, 2, 19-37.
