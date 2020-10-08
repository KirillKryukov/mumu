#!/usr/bin/env perl
#
# mumu.pl  -  Implementation of the Multi-Multi-FASTA/Q file format
#
# Version 0.4.0 (October 8, 2020)
#
# By Kirill Kryukov
#
# https://github.com/KirillKryukov/mumu
#
# See LICENSE and README.md files in the GitHub repository for details.
#

use strict;
use File::Basename qw(basename dirname);
use File::Glob qw(:bsd_glob);
use File::Path qw(make_path);
use Getopt::Long qw(:config pass_through);

my ($dir) = ('.');
my ($format, $stdin, $unpack, $no_ext, $add_ext, $command_template, $overwrite, $tag_all, $separator, $help, $version);
GetOptions(
    'dir=s'   => \$dir,
    'fasta'   => sub { $format = 'fasta'; },
    'fastq'   => sub { $format = 'fastq'; },
    'stdin'   => \$stdin,
    'unpack'  => \$unpack,
    'no-ext'  => \$no_ext,
    'add-ext=s' => \$add_ext,
    'cmd=s'     => \$command_template,
    'overwrite' => \$overwrite,
    'sep'     => \$separator,
    'all'     => \$tag_all,
    'help'    => \$help,
    'version' => \$version,
);

if ($version)
{
    print q`Multi-Multi-FASTA/Q codec, version 0.4.0, 2020-10-08
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
  --cmd CMD   - Run CMD on each file (may include {FILE}, {PATH}, {FILE-NO-EXT}, {PATH-NO-EXT})
  --sep 'STR' - Use STR as separator (default: '>' for fasta, '@' for fastq)
  --all       - Tag all sequences with filename
  --fasta     - Process FASTA-formatted data (default)
  --fastq     - Process FASTQ-formatted data
  --stdin     - Read list of files to pack from standard input
  --no-ext    - Don't store file extensions when packing
  --add-ext EXT - Add extension EXT to each processed filename
  --overwrite - Overwrite existing files when unpacking
  --help      - Print this help and exit
  --version   - Print version and exit
`;
    exit;
}


if (!defined $format) { $format = 'fasta'; }
if (!defined $separator) { $separator = ($format eq 'fasta') ? '>' : '@'; }
my $fastq = ($format eq 'fastq');

if (defined $command_template and $command_template !~ /\{(FILE|PATH|FILE-NO-EXT|PATH-NO-EXT)\}/)
{
    die "--cmd must include either {FILE}, {PATH}, {FILE-NO-EXT}, or {PATH-NO-EXT}\n";
}


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
                if ($no_ext) { $path =~ s/\.[^\.\/\\]*$//; }
                if (defined $add_ext) { $path .= $add_ext; }

                if ($path ne $prev_path)
                {
                    if ($path =~ /[\/\\]/)
                    {
                        my $d = dirname($path);
                        make_path($d);
                        if (!-e $d or !-d $d) { die "Can't create directory \"$d\"\n"; }
                    }

                    if (defined $command_template)
                    {
                        if (!exists($file_seen{$path}) or !-e $path or $overwrite)
                        {
                            my ($base, $path_no_ext, $base_no_ext) = parse_path($path);
                            my $cmd = $command_template;
                            $cmd =~ s/\{PATH\}/$path/g;
                            $cmd =~ s/\{FILE\}/$base/g;
                            $cmd =~ s/\{PATH-NO-EXT\}/$path_no_ext/g;
                            $cmd =~ s/\{FILE-NO-EXT\}/$base_no_ext/g;
                            open($OUT, '|-', $cmd) or die "Can't run \"$cmd\"\n";
                            $file_seen{$path} = 1;
                        }
                        else { undef $OUT; }
                    }
                    else
                    {
                        my $actual_path = $path;
                        if ($no_ext) { $actual_path =~ s/\.[^\.\/\\]*$//; }
                        if (defined $add_ext) { $actual_path .= $add_ext; }
                        if (exists $file_seen{$path})
                        {
                            open($OUT, '>>', $actual_path) or die "Can't append to file \"$actual_path\"\n";
                            binmode $OUT;
                        }
                        else
                        {
                            if (!-e $actual_path or $overwrite)
                            {
                                open($OUT, '>', $actual_path) or die "Can't create file \"$actual_path\"\n";
                                binmode $OUT;
                                $file_seen{$path} = 1;
                            }
                            else { undef $OUT; }
                        }
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
        my $IN;
        if (defined $command_template)
        {
            my $path = $file;
            my ($base, $path_no_ext, $base_no_ext) = parse_path($path);
            my $cmd = $command_template;
            $cmd =~ s/\{PATH\}/$path/g;
            $cmd =~ s/\{FILE\}/$base/g;
            $cmd =~ s/\{PATH-NO-EXT\}/$path_no_ext/g;
            $cmd =~ s/\{FILE-NO-EXT\}/$base_no_ext/g;
            open($IN, '-|', $cmd) or die "Can't run \"$cmd\"\n";
        }
        else
        {
            open($IN, '<', $file) or die "Can't open \"$file\"\n";
        }
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
                        print $_, $separator, prepare_file_path_to_store($file), "\n";
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
                        print $_, $separator, prepare_file_path_to_store($file), "\n";
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
            print $first_line, $separator, prepare_file_path_to_store($file), "\n";
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


sub parse_path
{
    my ($path) = @_;
    my $path_no_ext = $path;
    $path_no_ext =~ s/\.[^\.]*$//;
    my $base = basename($path);
    my $base_no_ext = $base;
    $base_no_ext =~ s/\.[^\.]*$//;
    return ($base, $path_no_ext, $base_no_ext);
}


sub prepare_file_path_to_store
{
    my ($path) = @_;
    if ($no_ext) { $path =~ s/\.[^\.\/\\]*$//; }
    if (defined $add_ext) { $path .= $add_ext; }
    $path =~ s/\\/\//g;
    return $path;
}
