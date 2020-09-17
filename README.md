# Multi-Multi-FASTA file format

DNA and protein sequences are often stored in [FASTA format](https://en.wikipedia.org/wiki/FASTA_format).
These days we put multiple sequences in a FASTA file,
but originally FASTA file was supposed to contain just a single sequence.
A file with multiple sequences was called "Multi-FASTA".

Now, what if you want to combine not only multiple sequences, but multiple FASTA files into a single file?
You could use tar, but the resulting .tar file is binary and not compatible with FASTA-processing tools.
Simply concatenating the individual files together would lose the file names.

Hence, this proposal of Multi-Multi-FASTA file format (mumu).
It's a FASTA file, where sequence headers can have an optional ">filename" suffix.
So, the complete sequence header looks like ">sequence name>filename".
Such header indicates that this, and all subsequenct sequences belong to the file "filename".
This allows deconstructing the Multi-Multi-FASTA file back to individual FASTA files.

Importantly, Multi-Multi-FASTA file can be processed with FASTA-compatible tools.
It can be compressed and shared with collaborators.
It can be searched with homology search tools, etc.
When necessary, it can be deconstructed back into original FASTA files.

## Implementation

The script _mumu.pl_ from this repo is the reference implementation.
It allows both packing and unpacking a Multi-Multi-FASTA file.

### Installing

Prerequisites: git (for downloading), perl.
E.g., to install on Ubuntu: `sudo apt install git perl`.
On Mac OS you may have to install Xcode Command Line Tools.

Downloading:

`git clone https://github.com/KirillKryukov/mumu.git`

Feel free to place the _mumu.pl_ script where you need it.

### Packing multiple files into a Multi-Multi-FASTA file

`mumu.pl data/*.fa >all.fa` - Combine all .fa files in "data" directory, store the result in a file "all.fa".

`mumu.pl --dir data *.fa >all.fa` - Same thing, but chdir into the "data" directory first. The filenames stored in the output will have no directory part.

`mumu.pl --dir data --sep '<' *.fa >all.fa` - Use '<' as a separator between sequence name and filename in the output.

`mumu.pl --dir data --all *.fa >all.fa` - Add filename to all sequence names. By default only the first sequence is tagged with filename.

`mumu.pl <list.txt >all.fa` - Pack files listed in "list.txt" into "all.fa".

### Unpacking a Multi-Multi-FASTA file

`mumu.pl --unpack all.fa` - Unpacks "all.fa" into individual files.

`mumu.pl --unpack --dir new all.fa` - Creates directory "new", enters it, and then unpacks "all.fa".

`mumu.pl --unpack --sep '<' all.fa` - Unpacks file where "<" was used as separator between sequence name and filename.

## FAQ

**Why not put the filename first, like ">filename>sequence name" ?**<br>
The reason is that in many cases sequence names begin with accession number.
Putting filename in the end keeps compatibility with software tools that read only accession number and ignore the rest of the name.

**Is it OK to repeat the ">" in sequence name?**<br>
By default, sequence name and filename are separated by the ">" character,
for the reason that this character not normally found in sequence names.
However, some tools may possibly have problem when seeing a second ">" in one line.
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
During unpacking, the missing directories will be created.

**What about FASTQ data?**<br>
Naturally the same principle can be also applied to FASTQ data.
The current implementation does not support FASTQ, but it may be added in the future.

**What filename extension should be used for Multi-Multi-FASTA files?**<br>
The extension "mumu" can be used by default.
Also, the same extension with the original data can be used, e.g. "fa". or "fq", to distinguish FASTA and FASTQ data.
When compressing the Multi-Multi-FASTA file with [naf](https://github.com/KirillKryukov/naf),
the "nafnaf" extension is recommended, to indicate the presence of multiple files within the archive.

## Example application - compressing related genomes

Suppose we have a set of related genomes, for example, 1,697 genomes of <i>Helicobacter pylori</i>.
Uncompressed they occupy 2.8 GB in FASTA format.
Compressed one by one using gzip results in a 804 MB set of files.
A better compressor, such as [naf](https://github.com/KirillKryukov/naf), brings the size down to 675 MB.
However the genomes still remain in 1,697 separate files.

Let's try the two most common ways of bundling the genomes together in a single file: zip and tar.gz:
we obtain a single archive of 767 and 803 MB, respectively.
Although we now have single file, convenient for sharing or moving around, the size is still large.
Also, accessing the sequence data now requires de-constructing the archive back into individual files.

A better compressor may produce a smaller archive.
But the necessity to restore the original files before working on them will remain.

Now, what happens if we combine the genomes into a Multi-Multi-FASTA file,
and then compress it with a compressor such as [naf](https://github.com/KirillKryukov/naf)?
We obtain a file that is only 80 MB - 10 times smaller and easy to send over network.

Importantly, FASTA-formatted sequences contained in this archive can be accessed by simply decompressing and piping the data to a FASTA-compatible tool.
This means that many analyses can be performed without unpacking the archive, and without storing 1,697 files on filesystem.
Only when necessary we will de-construct the archive into individual FASTA files.

**Example commands:**

Compressing:<br>
`mumu.pl --dir 'Helicobacter' 'Helicobacter pylori*' | ennaf -22 --text -o Hp.nafnaf`

Decompressing and unpacking:<br>
`unnaf Hp.nafnaf | mumu.pl --unpack --dir 'Helicobacter'`
