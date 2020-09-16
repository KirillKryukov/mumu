# Multi-Multi-FASTA file format

DNA and protein sequences are often stored in [FASTA format](https://en.wikipedia.org/wiki/FASTA_format).
These days we put multiple sequences in a FASTA file, but originally FASTA file contained a single sequence.
A file with multiple sequences was called "Multi-FASTA".

Now, what if you want to combine not only multiple sequences, but multiple FASTA files into a single file?
You could use tar, but the resulting .tar file is binary and not compatible with FASTA.
Simply concatenating the files together would lose the file names.

Hence, this proposal of Multi-Multi-FASTA file format (mumu).
It's a FASTA file, where sequence headers can have an optional ">filename" suffix.
So, the complete sequence header looks like ">sequence name>filename".
Such header indicates that this, and all subsequenct sequences belong to the file "filename".
This allows deconstructing the mumu file back to individual fasta files.

## Format details

Why not put the filename first, like ">filename>sequence name" ?
The reason is that in many cases sequence names begin with accession number.
Putting filename in the end keeps compatibility with software tools that read only accession number and ignore the rest of the name.

By default, the original sequence name and the filename are separated by the ">" character.
The reason is that this character not normally found in sequence names.
However, theoretically some tools may have problem when seeing a second ">" in one line.
In such cases, it's possible to use another character.
Naturally, when using custom separator, the same separator has to be indicated when packing and unpacking the mumu file.

Should all sequences be tagged with filenames, or only first sequence of each file?
This depends on the usage scenario.
If the workflow involves re-ordering or filtering of sequences, then tagging each sequence may be necessary.
On the other hand, if all sequences will be retained, then tagging only first sequence per file is more compact.
The format and implementation support both cases.

Naturally the same principle can be also applied to FASTQ data.
The current implementation does not support FASTQ, but it may be added in the future.

## Implementation

The script "mumu.pl" from this repo is the reference implementation.
It allows both packing and unpacking a mumu file.

### Installing

Prerequisites: git (for downloading), perl.
E.g., to install on Ubuntu: `sudo apt install git perl`.
On Mac OS you may have to install Xcode Command Line Tools.

Downloading:

`git clone https://github.com/KirillKryukov/mumu.git`

Feel free to place the mumu.pl script where you need it.

### Packing multiple files into a mumu file

`mumu.pl data/*.fa >all.fa` - Combine all .fa files in "data" directory, store the result in a file "all.fa".

`mumu.pl --dir data *.fa >all.fa` - Same thing, but chdir into the "data" directory first. The filenames stored in the output will have no directory part.

`mumu.pl --dir data --sep '<' *.fa >all.fa` - Use '<' as a separator between sequence name and filename in the output.

`mumu.pl --dir data --all *.fa >all.fa` - Add filename to all sequence names. By default only the first sequence is tagged with filename.

`mumu.pl <list.txt >all.fa` - Pack files listed in "list.txt" into "all.fa".

### Unpacking a mumu file

`mumu.pl --unpack all.fa` - Unpacks "all.fa" into individual files.

`mumu.pl --unpack --dir new all.fa` - Creates directory "new", enters it, and then unpacks "all.fa".

`mumu.pl --unpack --sep '<' all.fa` - Unpacks file where "<" was used as separator between sequence name and filename.

