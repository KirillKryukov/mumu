#!/usr/bin/env perl

use strict;
use File::Basename qw(dirname);
use File::Glob qw(:bsd_glob);
use File::Path qw(make_path);
use Getopt::Long qw(:config pass_through);

my ($dir, $separator, $stdin, $unpack, $tag_all) = ('.', '>');
GetOptions(
    'dir=s'  => \$dir,
    'stdin'  => \$stdin,
    'unpack' => \$unpack,
    'sep'    => \$separator,
    'all'    => \$tag_all,
);


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
    while (<STDIN>)
    {
        if (substr($_, 0, 1) eq '>')
        {
            my $s = index($_, $separator, 1);
            if ($s > 0)
            {
                if ($OUT) { close $OUT; }

                my $path = substr($_, $s + 1);
                $path =~ s/[\x0D\x0A]+$//;
                if ($path ne $prev_path)
                {
                    if ($file_seen{$path})
                    {
                        open($OUT, '>>', $path) or die "Can't append to file \"$path\"\n";
                    }
                    else
                    {
                        if ($path =~ /[\/\\]/)
                        {
                            my $d = dirname($path);
                            make_path($d);
                            if (!-e $d or !-d $d) { die "Can't create directory \"$d\"\n"; }
                        }
                        open($OUT, '>', $path) or die "Can't create file \"$path\"\n";
                        $file_seen{$path} = 1;
                    }
                    binmode $OUT;
                    $prev_path = $path;
                }

                print $OUT substr($_, 0, $s), "\n";
                next;
            }
        }

        if (!$OUT) { die "Input is not in multi-multi-fasta format\n"; }
        print $OUT $_;
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
