#!/usr/bin/env perl
#
# mumu.pl  -  Implementation of the Multi-Multi-FASTA/Q file format
#
# Version 0.3.0 (September 30, 2020)
#
# By Kirill Kryukov
#
# https://github.com/KirillKryukov/mumu
#
# See LICENSE and README.md files in the GitHub repository for details.
#

use strict;
use File::Basename qw(dirname);
use File::Glob qw(:bsd_glob);
use File::Path qw(make_path);
use Getopt::Long qw(:config pass_through);

my ($dir) = ('.');
my ($format, $stdin, $unpack, $overwrite, $tag_all, $separator, $help, $version);
GetOptions(
    'dir=s'   => \$dir,
    'fasta'   => sub { $format = 'fasta'; },
    'fastq'   => sub { $format = 'fastq'; },
    'stdin'   => \$stdin,
    'unpack'  => \$unpack,
    'overwrite' => \$overwrite,
    'sep'     => \$separator,
    'all'     => \$tag_all,
    'help'    => \$help,
    'version' => \$version,
);

if ($version)
{
    print q`Multi-Multi-FASTA/Q codec, version 0.3.0, 2020-09-30
by Kirill Kryukov, https://github.com/KirillKryukov/mumu
`;
    exit;
}

if ($help)
{
    print q`Packing:
    mumu.pl [OPTIONS] [FILE ..] [<LIST.txt] >packed.fa
Unpacking:
    mumu.pl --unpack [OPTIONS] <packed.fa
Options:
  --dir DIR   - Enter DIR before packing or unpacking
  --sep 'STR' - Use STR as separator (default: '>' for fasta, '@' for fastq)
  --all       - Tag all sequences with filename
  --fasta     - Process FASTA-formatted data (default)
  --fastq     - Process FASTQ-formatted data
  --stdin     - Read list of files to pack from standard input
  --overwrite - Overwrite existing files when unpacking
  --help      - Print this help and exit
  --version   - Print version and exit
`;
    exit;
}


if (!defined $format) { $format = 'fasta'; }
if (!defined $separator) { $separator = ($format eq 'fasta') ? '>' : '@'; }
my $fastq = ($format eq 'fastq');


my %file_seen;
my @files;


if ($unpack) { mumu_unpack(); }
else { mumu_pack(); }


sub mumu_unpack
{
    if ($dir ne '.')
    {
        if (!-e $dir)
        {
            make_path($dir);
            if (!-e $dir or !-d $dir) { die "Can't create directory \"$dir\"\n"; }
        }
        chdir $dir or die "Can't change directory to \"$dir\"\n";
    }

    my $OUT;
    my $prev_path = '';

    binmode STDIN;

    my $part_num = 0;
    while (<STDIN>)
    {
        if ( $fastq ? ($part_num == 0) : (substr($_, 0, 1) eq '>') )
        {
            my $s = index($_, $separator, 1);
            if ($s > 0)
            {
                if ($OUT) { close $OUT; }

                my $path = substr($_, $s + 1);
                $path =~ s/[\x0D\x0A]+$//;
                $path =~ s/^([a-zA-Z]:|[\/\\]|\.\.[\/\\])+//;
                $path =~ s/([\/\\])\.\.[\/\\]/$1/g;
                if ($path ne $prev_path)
                {
                    if ($file_seen{$path})
                    {
                        open($OUT, '>>', $path) or die "Can't append to file \"$path\"\n";
                        binmode $OUT;
                    }
                    else
                    {
                        if ($path =~ /[\/\\]/)
                        {
                            my $d = dirname($path);
                            make_path($d);
                            if (!-e $d or !-d $d) { die "Can't create directory \"$d\"\n"; }
                        }
                        if (!-e $path or $overwrite)
                        {
                            open($OUT, '>', $path) or die "Can't create file \"$path\"\n";
                            binmode $OUT;
                            $file_seen{$path} = 1;
                        }
                        else { undef $OUT; }
                    }
                    $prev_path = $path;
                }

                $_ = substr($_, 0, $s) . "\n";
            }
        }

        if ($OUT) { print $OUT $_; }
        if ($fastq) { $part_num = ($part_num + 1) & 3; }
    }

    if ($OUT) { close $OUT; }
}


sub mumu_pack
{
    if ($dir ne '.')
    {
        chdir $dir or die "Can't change directory to \"$dir\"\n";
    }

    foreach my $arg (@ARGV) { add_wildcard($arg); }

    if ($stdin)
    {
        while (my $line = <STDIN>)
        {
            $line =~ s/\s*[\x0D\x0A]+$//;
            if ($line eq '') { next; }
            add_wildcard($line);
        }
    }

    my $n_files = scalar(@files);
    if ($n_files < 1) { die "No input files specified\n"; }

    binmode STDOUT;

    foreach my $file (@files)
    {
        open (my $IN, '<', $file) or die "Can't open \"$file\"\n";
        binmode $IN;

        if ($tag_all)
        {
            if ($fastq)
            {
                my $part_num = 0;
                while (<$IN>)
                {
                    if ($part_num == 0)
                    {
                        s/[\x0D\x0A]+$//;
                        print $_, $separator, $file, "\n";
                        next;
                    }
                    print $_;
                    $part_num = ($part_num + 1) & 3;
                }
            }
            else
            {
                while (<$IN>)
                {
                    if (substr($_, 0, 1) eq '>')
                    {
                        s/[\x0D\x0A]+$//;
                        print $_, $separator, $file, "\n";
                        next;
                    }
                    print $_;
                }
            }
        }
        else
        {
            my $first_line = <$IN>;
            $first_line =~ s/[\x0D\x0A]+$//;
            print $first_line, $separator, $file, "\n";
            while (<$IN>) { print $_; }
        }

        close $IN;
    }
}


sub add_wildcard
{
    my ($wildcard) = @_;
    $wildcard =~ s/^'(.*)'$/$1/;
    if ($wildcard =~ /[\?\*]/) { foreach my $file (bsd_glob($wildcard)) { add_file($file); } }
    else { add_file($wildcard); }
}


sub add_file
{
    my ($file) = @_;
    if (exists $file_seen{$file}) { next; }
    $file_seen{$file} = 1;
    push @files, $file;
}
