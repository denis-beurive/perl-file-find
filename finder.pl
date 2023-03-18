#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use File::Spec::Functions qw(catfile rel2abs);
use Data::Dumper;

use constant K_FILES => 'files';
use constant K_DIRECTORIES => 'directories';

# List the content of a directory.
# @param $in_path The path to the directory to list.
# @return On success, a reference to a hash that contains 2 keys:
#         - 'files' (or `&K_FILES`) => a reference to an array of absolute paths to files.
#         - 'directories' (or `&K_DIRECTORIES`) => a reference to an array of absolute paths to (sub)directories.
#         On failure: undef.

sub ls {
    my ($in_path) = @_;
    my $dh;
    my @files = ();
    my @directories = ();

    $in_path = rel2abs($in_path);

    opendir $dh, $in_path or return(undef);
    while (readdir $dh) {
        next if ('.' eq $_) || ('..' eq $_);
        my $entry_absolute_path = catfile($in_path, $_);
        if (-f $entry_absolute_path) { push(@files, rel2abs($entry_absolute_path)) }
        elsif (-d $entry_absolute_path) { push(@directories, rel2abs($entry_absolute_path)) }
    }
    closedir $dh;

    return({
        &K_FILES       => \@files,
        &K_DIRECTORIES => \@directories
    })
}

sub always_true {
    my ($in_path) = @_;
    return(1);
}

# List the content of a directory, recursively.
# @param $in_path The path of the directory to list.
# @param %options:
#        - 'file_filter': reference to a function used to decide whether a file should be kept ot not.
#          The function's signature is: `sub function { my ($file_path) = @_; ... return $status }`
#                                       - if `$status` is non-null, then the file is kept.
#                                       - if `$status` is null, then the file is not kept.
#          Example: `sub my_file_filter { return shift =~ m/\.c$/; }`
#                   Keep only the files whose names end with the suffix ".c".
#        - 'file_directory': reference to a function used to decide whether a directory should be kept ot not.
#          The function's signature is: `sub function { my ($directory_path) = @_; ... return $status }`
#                                       - if `$status` is non-null, then the directory is kept.
#                                       - if `$status` is null, then the directory is not kept.
#                                         And all files within this directory are rejected (as well),
#                                         but not the subdirectories. The subdirectories will be visited (but
#                                         not necessarily kept - depending on the filtration status).
#          Example: `sub my_directory_filter { return ! (shift =~ m/examples$/); }`
#                   Reject all directories whose associated paths end with the string "examples".
#                   Keep all other directories.
# @return A reference to a hash which keys are absolute paths to directories.
#         And values are references to arrays that contain lists of absolute files paths.
#         That is:  { '/path/to/dir1' => ['/path/to.file1',...],
#                     '/path/to/dir2' => ['/path/to.file1',...],
#                     ... }
# @note All paths returned by this function are *absolute real* paths.

sub find {
    my ($in_path, %options) = @_;
    my @s_stack = ();
    my %files = ();
    my $filter_file = exists($options{'file_filter'}) ? $options{'file_filter'} : undef;
    my $filter_directory = exists($options{'directory_filter'}) ? $options{'directory_filter'} : \&always_true;

    $in_path = rel2abs($in_path);
    push(@s_stack, $in_path);

    while(int(@s_stack) > 0) {
        my $current_dir = pop(@s_stack);
        my $entries = ls($current_dir);


        if ($filter_directory->($current_dir)) {
            my @current_dir_files = @{$entries->{&K_FILES}};
            my $files = \@current_dir_files;

            if (defined($filter_file)) {
                my @filtered = ();
                foreach my $file (@current_dir_files) {
                    push(@filtered, $file) if $filter_file->($file);
                    $files = \@filtered;
                }
            }

            $files{$current_dir} = $files;
        }

        push(@s_stack, @{$entries->{&K_DIRECTORIES}});
    }

    return \%files;
}


# Define the filters for files and directories (optional).
sub my_file_filter { return shift =~ m/\.c$/; }
sub my_directory_filter { return ! (shift =~ m/examples$/); }

# Select all files under the directory "../src".
my $files = find('../src', 'file_filter' => \&my_file_filter, 'directory_filter' => \&my_directory_filter);
printf Dumper $files;
