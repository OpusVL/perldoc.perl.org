package OpusVL::PerlDoc;

use 5.006;
use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";

use Getopt::Long;
use Data::Dumper;
use Env;
use LWP::UserAgent ();
use HTML::TreeBuilder;
use Devel::PatchPerl;
use File::Path qw(make_path remove_tree);
use Crypt::Digest::SHA256 qw( sha256_file_hex );
use Archive::Tar;
use Capture::Tiny ':all';
use Try::Tiny;
use File::Find;
use Cwd;
use Template;
use Perldoc::Config;
use JSON::MaybeXS;

=head1 NAME

OpusVL::PerlDoc

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Automatically download, build, extract and convert all stable versions of perl into objects.

The runnable created by installing this is called 'perldoc-tramsform' as to not collide with 
any other possible binaries or executables.

=head1 Arguments

The following may be used as enviromental variables or console arguments,
if both exist the console version will be used.

=head2 --build-dir (ENV: BUILDDIR)

This is defaulted to ./builds

Set the direcory where perl modules will be downloaded, extracted, built and scanned from.

=head2 --output-dir (ENV: OUTPUTDIR)

This is defaulted to ./outputs

Set the directory to output the JSON objects representative of the manual pages.

=head2 --remote-parent (ENV: REMOTE)

This is defaulted to https://www.cpan.org/src/5.0/

This is where is scanned for perl versions to download and build, the default is: L<https://www.cpan.org/src/5.0/>

=head1 AUTHOR

OpusVL, C<< <community at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-opusvl-perldoc at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=OpusVL-PerlDoc>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc OpusVL::PerlDoc

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=OpusVL-PerlDoc>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/OpusVL-PerlDoc>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/OpusVL-PerlDoc>

=item * Search CPAN

L<https://metacpan.org/release/OpusVL-PerlDoc>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2018 OpusVL.

Copyright (c) 2018, OpusVL
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of OpusVL nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL OpusVL BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

# A neat place to store things
my $global = {
    ua  => do { my $ua = LWP::UserAgent->new; $ua->timeout(10); $ua->env_proxy; $ua },
    tar => Archive::Tar->new,
    tt => Template->new(),
    hints => {
        '5_8_8' => 'exit 1',
        '5_8_9' => 'exit 1',
        '5_10_0' => 'exit 1',
        '5_10_1' => 'exit 1',
        '5_12_0' => 'exit 1',
        '5_12_1' => 'exit 1',
        '5_12_2' => 'exit 1',
        '5_12_3' => 'exit 1',
        '5_12_4' => 'exit 1',
        '5_12_5' => 'exit 1',
        '5_14_0' => 'exit 1',
        '5_14_1' => 'exit 1',
        '5_14_2' => 'exit 1',
        '5_14_3' => 'exit 1',
        '5_14_4' => 'exit 1',
#        default => 'exit 1',
        default => 'mkdir -p ../env && sh Configure -de -Dprefix="../env" && make && make install',
    },
    force => ($ARGV[0] && $ARGV[0] eq 'force') ? "yes" : "no",
    js => JSON::MaybeXS->new()
};

sub main { 
    # Download a list of the latest perls

    # Download the tarball + sha

    # Verify the sha

    # Extract the tarball 

    # Setup enviroment



    # Find all remote sources
    # Verify they are present in the local filesystem
    # Run 
    find_sources();
 #   verify_local();
 #   fetch_remotes();        # Fetch all required build files
 #   do_work();              # Do work based on the state the perl is in
 #   sleep 60*60*24;
}

sub fetch_remotes {
    foreach my $major (keys %{ $global->{sources} }) {
        foreach my $minor (keys %{ $global->{sources}->{$major} }) {
            if (!$global->{sources}->{$major}->{$minor}->{state}) {
                $global->{sources}->{$major}->{$minor} = fetch_tarball($global->{sources}->{$major}->{$minor});
            }
        }
    }
}

sub do_work {
    my $ttenv = {};
    my $latest = { count => 0, major => 0, minor => 0 };
    my $me = {};
    my @versions = ();

    foreach my $major (keys %{ $global->{sources} }) {
        foreach my $minor (keys %{ $global->{sources}->{$major} }) {
	    if ($global->{sources}->{$major}->{$minor}->{state} eq 'podextract_ok') { $global->{sources}->{$major}->{$minor}->{state} = 'build_ok' }
            if ($global->{sources}->{$major}->{$minor}->{state} eq 'download_ok') {
                $global->{sources}->{$major}->{$minor} = extract_tarball($global->{sources}->{$major}->{$minor});
            }
            if ($global->{sources}->{$major}->{$minor}->{state} eq 'extracted_ok') {
                $global->{sources}->{$major}->{$minor} = build_perl($global->{sources}->{$major}->{$minor});
            }
            if ($global->{sources}->{$major}->{$minor}->{state} eq 'build_ok' || ($global->{force} && $global->{sources}->{$major}->{$minor}->{state} eq 'done') ) {
                my $rp = $global->{sources}->{$major}->{$minor};
                # this is the magical path that needs to change URL to  outputs/5.major.minor
                my $path_to_output  = join('/',$global->{config}->{'output-dir'},'5.'.$major.'.'.$minor);

                {
                    # Write out the POD extractor script
                    my $pod_extractor   = join('/',$rp->{local_path},'extract_pod.sh');
                    my $built_perl_dir  = join('/',$rp->{local_path},'env');
                    my $built_perl_bin  = join('/',$built_perl_dir,'bin','perl');
                    my $pod_gen_path    = join('/',$Bin,'build-perldoc-html.pl');
                    open(my $fh,'>',$pod_extractor);
                    print $fh '#!/bin/sh'."\n";
                    print $fh 'cd "'.$built_perl_dir.'"'." && mkdir -p \"$path_to_output\"\n";
                    print $fh 'perl "'.$pod_gen_path.'" -output-path '.$path_to_output.' -perl '.$built_perl_bin.' -major '.$major.' -minor '.$minor;
                    close($fh);
                }

                my $extractor = join('/',$rp->{local_path},'extract_pod.sh');
                print "Extracting pods for ($major,$minor)\n";
                my @args = ('sh',$extractor);
                my ($output, $exit) = capture_merged { system(@args) };
                print "Extracting Pods(Output): $output\n";
                print "Extracting pods: $output\n";

                # Path test for pod extraction
                my $pod_test = join('/',$path_to_output,'index-faq.html');
                if (-e $pod_test) {
                    $global->{sources}->{$major}->{$minor} = set_state($rp,'podextract_ok');
                    $ttenv->{versions}->{$major}->{$minor} = $minor;
                    push @versions,[$major,$minor];
                } else {
                    $global->{sources}->{$major}->{$minor} = set_state($rp,'podextract_bad');
                }
            }
        }
    }

    foreach my $version (@versions) {
        my $major = $version->[0];
        my $minor = $version->[1];

        # THIS NEEDS TO GO ON THE VERY END AFTER POD_EXTRACTED
        my $vconcat = join('',$major,$minor);
        if ($vconcat > $latest->{count}) { 
            $latest->{count} = $vconcat;
            $latest->{major} = $major;
            $latest->{minor} = $minor;
        }
    }

    foreach my $version (@versions) {
        my $major = $version->[0];
        my $minor = $version->[1];

        # Add this to me TT and output index
        $me->{major} = $major;
        $me->{minor} = $minor;

        # Add MAJOR/MINOR for 'me' to TT....
        $ttenv->{me} = $me;
        $ttenv->{latest} = $latest;

        {
            my $output = "";
            $global->{tt}->process('templates/main_index.tt',$ttenv,\$output);

            # Write the output to the output directory
            my $index_path = join('/',$global->{config}->{'output-dir'},'5.'."$major.$minor");
            make_path($index_path);
            write_html($index_path."/index.html",$output);
        }

        # Clear ME for the next pass
        $me = {};
    }


    # Generate the main index
    if (!-e 'templates/main_index.tt') {
        warn "No main_index.tt found";
        die;
    }

    # Pass the highest versions to TT and remove any me records
    $ttenv->{latest} = $latest;
    delete $ttenv->{me};

    # Lets create an index.html in the output dir
    my $output = "";
    $global->{tt}->process('templates/main_index.tt',$ttenv,\$output);

    # Write the output to the output directory
    my $main_index = join('/',$global->{config}->{'output-dir'},'index.html');
    write_html($main_index,$output);

    # Create a symlink to the latest version
    my $link_latest_path = join('',$global->{config}->{'output-dir'},'.default');
    my $vconcat = join('.',5,$latest->{major},$latest->{minor});
    my $link_latest_base = join('',$global->{config}->{'output-dir'},$vconcat);
    open(my $fh,'>','/latest');
    print $fh $link_latest_base;
    close($fh);
    open(my $fh,'>','/target');
    print $fh $link_latest_path;
    close($fh);


    # Write the passed jsons out to passed.json
    my $json_path = join('/',$global->{config}->{'output-dir'},'versions.json');
    open(my $fh,'>',$json_path);
    print $fh $global->{js}->encode($ttenv);
    close($fh);
}

sub write_html {
    my ($path,$data) = @_;

    open(my $fh,'>',$path);
    print $fh $data;
    close($fh);
}


sub make_writable { return chmod 0755, $File::Find::name }

sub build_perl {
    my $rp = shift;
    my $build_dir       = join('/',$rp->{local_path},$rp->{rawfilename});
    my $build_log       = join('/',$rp->{local_path},'build.log');

    # Fix broken sources (hopefully)
    find(\&make_writable, $build_dir);
    my $version = Devel::PatchPerl->determine_version($build_dir);
    my ($major,$minor) = $version =~ m@5\.(\d+)\.(\d+)@;

    if ($major <= 12 || ($major == 12 && $minor < 4)) {
        print "WARNING: (major <= 12 || major == 12 && minor < 4)) requires manually adding -lm to the Makefiles\n";
    }

    {
        my $build = $global->{hints}->{default};
        my $pversion = join('_',5,$major,$minor);
        print "Looking for hint: $pversion\n";
        if ($global->{hints}->{$pversion}) { 
            $build = $global->{hints}->{$pversion};
            print "Using HINT for $pversion: $build\n";
        }
        open(my $fh,'>','/tmp/buildperl.sh');
        print $fh '#!/bin/sh'."\n";
        print $fh "cd \"$build_dir\" && $build";
        close($fh);
    }

    print "Compiling for: $build_dir\n";
    my @args = ('sh','/tmp/buildperl.sh');
    my ($output, $exit) = capture_merged { system(@args) };

    {
        open(my $fh,'>',$build_log);
        local $/;
        print $fh $output;
        close($fh);
    }

    print "Compile for: $build_dir complete ($exit)\n";

    if ($exit) {
        return set_state($rp,'build_bad');
    } else {
        return set_state($rp,'build_ok');
    }
}

sub extract_tarball {
    my $rp = shift;
    my $local_path = $rp->{local_path} // die "No local_path specified";
    my $local_fn = join("/",$rp->{local_path},$rp->{filename});
    print "Extracting for: $local_fn\n";
    $global->{tar}->setcwd($rp->{local_path});
    $global->{tar}->read($local_fn);
    $global->{tar}->extract();
    print "Extraction complete for: $local_fn\n";
    # Have to guess this worked :(
    return set_state($rp,'extracted_ok');
}

sub fetch_tarball {
    my $rp = shift;

    my @download = (
        { 
            request => HTTP::Request->new( GET => $rp->{download_checksum} ),
            filename => $rp->{$rp->{checksum}}
        },
        {
            request => HTTP::Request->new( GET => $rp->{download_tarball} ),
            filename => $rp->{filename}
        },
    );

    my $local_dir = join('/',$global->{config}->{'build-dir'},$rp->{rawfilename});
    mkdir($local_dir);

    foreach my $target (@download) {
        my $local_fn = $target->{filename};
        my $local_path = join('/',$local_dir,$local_fn);
        my $res = $global->{ua}->request( $target->{request}, $local_path );
        if ($res->is_success) {
                if ($local_fn !~ m@\Q$rp->{checksum}\E@) {
                    my $sha256_local = sha256_file_hex($local_path);
                    my $sha256_authoritive = do {
                        local $/;
                        open(my $fh,'<',join('/',$local_dir,$rp->{$rp->{checksum}}));
                        my $read = <$fh>;
                        close($fh);
                        $read
                    };
                    if ($sha256_local eq $sha256_authoritive) {
                        print "Success downloading: $local_fn SHA256( MATCH $sha256_local )\n";
                        $rp = set_state($rp,'download_ok');
                    } else {
                        print "Refusing to proceed with $local_fn SHA256( LOCAL: $sha256_local AUTHORITIVE: $sha256_authoritive )\n";
                        remove_tree($local_dir);
                    }
                } else {
                    print "Success downloading: $local_fn\n";
                }
        }
        else {
            remove_tree($local_dir);
            print "Failure downloading: $local_fn\n";
            last;
        }
    }

    return $rp;
}

sub set_state {
    my ($rp,$state) = @_;
    my $local_path = join('/',$rp->{local_path},'.state');
    $rp->{state} = $state;
    open(my $fh,'>',$local_path);
    print $fh $state;
    close ($fh);
    return $rp;
}

sub get_state {
    my $rp = shift;
    my $local_path = join('/',$rp->{local_path},'.state');
    my $state;
    if (-e $local_path) {
        local $/;
        open(my $fh,'<',$local_path);
        $state = <$fh>;
        close ($fh);
    }
    return $state;
}

sub verify_local {
    foreach my $major (keys %{ $global->{sources} }) {
        foreach my $minor (keys %{ $global->{sources}->{$major} }) {
            if (! checksane($major,$minor) ) { $global->{sources}->{$major}->{$minor}->{state} = require_source($major,$minor) }
        }
    }
}

sub find_sources {
    # Gather command line and enviromental values
    $global->{config} = do {
        # Defaults
        my $pwd = getcwd;
        my $config = {
            'build-dir' => "$pwd/builds",
            'output-dir' => "$pwd/outputs/",
            'remote-parent' => 'https://www.cpan.org/src/5.0/'
        };

        foreach my $key (keys %{$config}) {
            if ($ENV{uc($key)}) { $config->{$key} = $ENV{$key} }
        }

        GetOptions(
            'build-dir:s'     =>  \$config->{'build-dir'},
            'output-dir:s'    =>  \$config->{'output-dir'},
            'remote-parent:s' =>  \$config->{'remote-parent'} 
        );

        $config;
    };

    # Check the outputs directory is created, if not create it
    if (!-e $global->{config}->{'output-dir'}) {
        mkdir $global->{config}->{'output-dir'} or die $!;
    }

    # Same for the build directory
    if (!-e $global->{config}->{'build-dir'}) {
        mkdir $global->{config}->{'build-dir'} or die $!;
    }

    # Get all the versions availible on the remote site
    $global->{sources} = find_remotes();

    return 0;
}

sub checksane {
    my ($major,$minor) = @_;

    my $rp = $global->{sources}->{$major}->{$minor};

    return 1 if ( !$rp->{rawfilename} || !$rp->{checksum} || !$rp->{$rp->{checksum}} );
    return 0;
}

sub require_source {
    my ($major,$minor) = @_;

    # May as well get a shortcut to the files now
    my $rp = $global->{sources}->{$major}->{$minor};
    my $state_path = join('/',$rp->{local_path},'.state');

    # Lets see if we have a build directory for this perl
    my $error = 1;

    if (-e $rp->{local_path} && -e $state_path) {
        my $state = $rp->{state};
        if (!$state) {
            $error = 1;
        } 
        elsif ($state eq 'download_ok') { 
            print "Perl $major $minor, already downloaded\n";
            $error = 0;
        }
        elsif ($state eq 'extracted_ok') {
            print "Perl $major $minor, already extracted\n";
            $error = 0;
        }
        elsif ($state eq 'build_ok') {
            print "Perl $major $minor, already built\n";
            $error = 0;
        }
        elsif ($state eq 'build_bad') {
            print "Perl $major $minor, b0rked (compile issues see build.log)\n";
            $rp->{state} = 'extracted_ok';
            $error = 0;
        }
        elsif ($state eq 'podextract_ok') {
            print "Perl $major $minor, Complete\n";
            $rp->{state} = 'done';
            $error = 0;
        }
        elsif ($state eq 'podextract_bad') {
            print "Perl $major $minor, Built but failed pod extract (retry)\n";
            $rp->{state} = 'build_ok';
            $error = 0;
        }
        else {
            warn "$major $minor state: $state (Force rebuild)";
            $error = 1;
        }
    }

    if ($error) { 
        remove_tree($rp->{local_path});
        return;
    } else {
        return $rp->{state};
    }
}

sub find_remotes {
    my $tree;
    my $return;

    my $response = $global->{ua}->get( $global->{config}->{'remote-parent'} );
    if ($response->is_success) {
        $tree = HTML::TreeBuilder->new_from_content($response->decoded_content);
    } else {
        warn "Failed to connect to destination server (".$global->{config}->{'remote-parent'}.")";
        warn $response->status_line;
        $tree = HTML::TreeBuilder->new_from_content("<html></html>");
    }

    for (@{  $tree->extract_links('a')  }) {
        my ($link, $element, $attr, $tag) = @$_;
        if ($link =~ m@^.*perl-5\.(\d+)\.(\d+)\.tar\.gz$@ || $link =~ m@^.*perl-5\.(\d+)\.(\d+)\.tar\.gz\.(sha256)\.txt$@) {
            my ($major,$minor,$checksum) = ($1,$2,$3);
            # Skip anything that is not a stable release
            next if ($major % 2 != 0);
            # Anything before this the POD is to crap tastic to worry about, only bother with stable releases
            next if ($major < 8 || ($major == 8 && $minor < 8));

            if ($checksum) {
                $return->{$major}->{$minor}->{$checksum} = $link;
                $return->{$major}->{$minor}->{"download_checksum"} = join('/',$global->{config}->{'remote-parent'},$link);
                $return->{$major}->{$minor}->{checksum} = $checksum;
            } else {
                my ($local_name) = $link =~ m#^(.*?)\.tar\.gz$#;
                $return->{$major}->{$minor}->{rawfilename} = $local_name;
                $return->{$major}->{$minor}->{filename} = $link;
                $return->{$major}->{$minor}->{local_path} = join('/',$global->{config}->{'build-dir'},$local_name);
                $return->{$major}->{$minor}->{state} = get_state($return->{$major}->{$minor});

                # Just incase we ever get a remote-parent with no ending /, // is processed as / anyway.
                $return->{$major}->{$minor}->{'download_tarball'} = join('/',$global->{config}->{'remote-parent'},$link);
            }
        }
    }
    return $return;
}

exit main($global); # End of OpusVL::PerlDoc
