package OpusVL::PerlDoc;

use 5.006;
use strict;
use warnings;

use LWP::UserAgent ();
use Template;
use Archive::Tar;
use JSON::MaybeXS;
use Data::Dumper;
use FindBin qw/$Bin/;
use lib "$Bin/lib";

use Getopt::Long;

# A neat place to store things
our $global = {
    ua      => do { my $ua = LWP::UserAgent->new; $ua->timeout(10); $ua->env_proxy; $ua },
    tar     => Archive::Tar->new,
    tt      => Template->new(),
    js      => JSON::MaybeXS->new(),
    rebuild => 0,
    modules => {
        source_sync => OpusVL::PerlDoc::SourceSync->new(),
        make_env    => OpusVL::PerlDoc::MakeEnv->new(),
        template    => OpusVL::PerlDoc::Template->new(),
        extract_pod => OpusVL::PerlDoc::ExtractPod->new(),
    },
};

my $schedule = {};

sub main {
    # Display progress
    $global->{ua}->show_progress(1);
    # Download a list of the latest perls
    $global->{modules}->{source_sync}->run();
    if (!$global->{rebuild}) {
        exit 0;
    }
    sync_state();
    # Setup enviroment (write make files)
    $global->{modules}->{make_env}->run();
    sync_state();
    # Execute the builds
    $global->{modules}->{make_env}->build();
    sync_state();
    # setup the perldoc base
    $global->{modules}->{extract_pod}->run();
    sync_state();
    # Finalize the indexs
    $global->{modules}->{extract_pod}->make_index();
    sync_state();
    # setup the perldoc base
    $global->{modules}->{extract_pod}->run();
    sync_state();
    # Finalize the indexs
    $global->{modules}->{extract_pod}->make_index();
    sync_state();

    return 1;
}

sub sync_state {
    foreach my $major (keys %{ $global->{perl} }) {
        foreach my $minor (keys %{ $global->{perl}->{$major} }) {
            my $env = $global->{perl}->{$major}->{$minor};
            my $state = $env->{state};
            my $state_path = $env->{state_path};
            open(my $fh,'>',$state_path);
            print $fh $global->{js}->encode($state);
            close($fh);
        }
    }
}

exit main();

package OpusVL::PerlDoc::ExtractPod;

use warnings;
use strict;

use Cwd;
use Env;
use Data::Dumper;
use HTML::TreeBuilder;
use Try::Tiny;
use File::Path qw(make_path remove_tree);
use Crypt::Digest::SHA256 qw( sha256_file_hex );
use Capture::Tiny ':all';
use FindBin qw/$Bin/;
use File::Copy::Recursive qw(dircopy);

sub new {
    my ($class,$base) = @_;

    # Some private stuff for ourself
    my $self = {};

    # Go with god my son
    bless $self, $class;
    return $self;
}

sub run {
    foreach my $major (keys %{ $global->{perl} }) {
        foreach my $minor (keys %{ $global->{perl}->{$major} }) {
            my $env = $global->{perl}->{$major}->{$minor};
            my $state = $env->{state}->{stage};

            if ($state !~ m/^pod_|build_ok/) {
                print "PodExtract($major,$minor): Skipped ($state)\n";
                next;
            }

            my $perl = "perl-$major.$minor";
            my $logpath = "/tmp/$perl-pod.log";
            my ($output, $exit, @args);

            chdir $env->{local_path};

            print  "POD extracting for for: perl-$major.$minor\n";

            @args = ('make','-f','Makefile.perldoc','pod');
            ($output, $exit) = capture_merged { system(@args) };

            print "Return value: $exit (Logfile written to: $logpath)\n";

            open(my $fh,'>',$logpath);
            print $fh $output;
            close($fh);

            chdir $global->{config}->{'work-dir'};

            if ($exit == 0) {
                $env->{state}->{stage} = 'pod_ok';
            }
            else {
                $env->{state}->{stage} = 'pod_bad';
            }

            $global->{perl}->{$major}->{$minor} = $env;
        }
    }
}

sub make_index {
    my @versions = ();
    my $env;
    my $ttenv = {};
    my $latest = { count => 0, major => 0, minor => 0 };
    my $me = {};

    chdir $Bin;

    foreach my $major (keys %{ $global->{perl} }) {
        foreach my $minor (keys %{ $global->{perl}->{$major} }) {
            $env = $global->{perl}->{$major}->{$minor};
            my $state = $env->{state}->{stage};
            if ($state ne 'pod_ok') {
                print "INDEX($major,$minor): Skipped ($state)\n";
                next;
            }
            push @versions,[$major,$minor];
        }
    }

    foreach my $version (@versions) {
        my $major = $version->[0];
        my $minor = $version->[1];

        # Kludge all known versions into here
        $ttenv->{versions}->{$major}->{$minor} = $minor;

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

        # For pretty
        print "INDEX($major,$minor): Generating\n";

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
            my $index_path = join('/',$global->{config}->{'pod-dir'},"5.$major.$minor");
            make_path($index_path);
            write_html($index_path."/index.html",$output);
        }

        {
            my $output = "";
            $global->{tt}->process('templates/404.tt',$ttenv,\$output);

            # Write the output to the output directory
            my $index_path = join('/',$global->{config}->{'pod-dir'},"5.$major.$minor");
            make_path($index_path);
            write_html($index_path."/404.html",$output);
        }

        # Clear ME for the next pass
        $me = {};
    }


    # Generate the main index = TODO HERE FUCKED
    if (!-e 'templates/main_index.tt') {
        warn "No main_index.tt found";
        die;
    }

    # Pass the highest versions to TT and remove any me records
    $ttenv->{latest} = $latest;
    delete $ttenv->{me};

    # Create an ordered list to make it easier to manage in tt
    $ttenv->{ordered_versions} = order_version(@versions);

    # Lets create an index.html in the output dir
    my $output = "";
    $global->{tt}->process('templates/main_index.tt',$ttenv,\$output);

    # Write the output to the output directory
    my $main_index = join('/',$global->{config}->{'pod-dir'},'index.html');
    write_html($main_index,$output);

    # Create a symlink to the latest version
    my $link_latest_path = join('',$global->{config}->{'pod-dir'},'.default');
    my $vconcat = join('.',5,$latest->{major},$latest->{minor});
    my $link_latest_base = join('',$global->{config}->{'pod-dir'},$vconcat);

    # Write the passed jsons out to passed.json
    my $json_path = join('/',$global->{config}->{'pod-dir'},'versions.json');
    open(my $fh,'>',$json_path);
    print $fh $global->{js}->encode($ttenv);
    close($fh);

    # Copy the required assets in too
    dircopy('Asset/',$global->{config}->{'pod-dir'}) or die $!;
}

sub order_version {
    my $vset;
    my $return = { index=>[] };
    my $i = -1;
    my $max = 0;

    foreach my $version (@_) {
        push @{$vset->[$version->[0]]},$version->[1];
        if ($version->[0] > $max) { $max = $version->[0] }
    }

    for (0..$max) {
        $i++;
        if (!$vset->[$i]) { next }
        push @{ $return->{index} }, $i;
        $return->{$i} = [];
        foreach my $minor (sort { $b <=> $a } @{ $vset->[$i] }) {
            push @{ $return->{$i} },$minor;
        }
    }

    # Reverse the primary index
    @{ $return->{index} } = sort { $b <=> $a } @{ $return->{index} };

    return $return;
}


sub write_html {
    my ($path,$data) = @_;

    open(my $fh,'>',$path);
    print $fh $data;
    close($fh);
}

1;

package OpusVL::PerlDoc::MakeEnv;

use warnings;
use strict;

use Cwd;
use Env;
use Data::Dumper;
use HTML::TreeBuilder;
use Try::Tiny;
use File::Path qw(make_path remove_tree);
use Crypt::Digest::SHA256 qw( sha256_file_hex );
use Capture::Tiny ':all';

sub new {
    my ($class,$base) = @_;

    # Some private stuff for ourself
    my $self = {};

    # Go with god my son
    bless $self, $class;
    return $self;
}

sub run {
    foreach my $major (keys %{ $global->{perl} }) {
        foreach my $minor (keys %{ $global->{perl}->{$major} }) {
            my $env = $global->{perl}->{$major}->{$minor};
            my $state = $env->{state}->{stage};

            if ($state ne 'download_ok') {
                print "EnvBuild($major,$minor): Skipped ($state)\n";
                next;
            }

            # Writing out the makefile
            open(my $fh,'>',$env->{make_path});
            my $makefile = print $fh $global->{modules}->{template}->makefile();
            close($fh);

            if ($makefile) {
                print "Env_OK($major,$minor) env_ok\n";
                $env->{state}->{stage} = 'env_ok';
            }
            else {
                print "Env_BAD($major,$minor) env_bad\n";
                $env->{state}->{stage} = 'env_bad';
            }
            $global->{perl}->{$major}->{$minor} = $env;
        }
    }
}

sub build {
    foreach my $major (keys %{ $global->{perl} }) {
        foreach my $minor (keys %{ $global->{perl}->{$major} }) {
            my $env = $global->{perl}->{$major}->{$minor};
            my $state = $env->{state}->{stage};

            if ($state ne 'env_ok') {
                print "Build($major,$minor): Skipped ($state)\n";
                next;
            }

            # Writing out the makefile
            my $perl = "perl-$major.$minor";
            my $logpath = "/tmp/$perl.log";
            my ($output, $response, $exit, @args);

            chdir $env->{local_path};

            print  "Starting buildsteps for: perl-$major.$minor\n";

            if (-e 'bin/perl') {
                $output = "Skipped";
                $response = "Skipped";
                $exit = 0;
            }
            else {
                @args = ('make','-f','Makefile.perldoc','patch');
                ($output, $exit) = capture_merged { system(@args) };
                print "Patch result($exit)\n";
                print "Beginning main build\n";
                if ($exit == 0) { 
                    @args = ('make','-f','Makefile.perldoc','install');
                    ($output, $exit) = capture_merged { system(@args) };
                    $response = "Unknown";
                }
            }

            print "Return value: $exit (Logfile written to: $logpath)\n";

            open(my $fh,'>',$logpath);
            print $fh $output;
            close($fh);

            chdir $global->{config}->{'work-dir'};

            if ($exit == 0)      {
                $env->{state}->{stage} = 'build_ok';
            }
            else {
                $env->{state}->{stage} = 'build_bad';
            }

            $response = $env->{state}->{stage};
            print "BuildSrc($major,$minor) $response\n";

            $global->{perl}->{$major}->{$minor} = $env;
        }
    }
}




package OpusVL::PerlDoc::SourceSync;

use warnings;
use strict;

use Cwd;
use Env;
use Data::Dumper;
use HTML::TreeBuilder;
use Try::Tiny;
use File::Path qw(make_path remove_tree);
use Crypt::Digest::SHA256 qw( sha256_file_hex );

sub new {
    my ($class,$base) = @_;

    # Some private stuff for ourself
    my $self = {};

    # Go with god my son
    bless $self, $class;
    return $self;
}

sub run {
    # Gather command line and enviromental values
    {
        # Defaults
        my $pwd = getcwd;
        my $config = {
            'work-dir'      => "$pwd/work/",
            'remote-parent' => 'https://www.cpan.org/src/5.0/',
            'pod-dir'       => "$pwd/work/output",
        };

        foreach my $key (keys %{$config}) {
            $global->{config}->{$key} = $config->{$key};
            if ($ENV{uc($key)}) { $global->{config}->{$key} = $ENV{$key} }
        }
    };

    # Check the outputs directory is created, if not create it
    if (!-e $global->{config}->{'work-dir'}) {
        mkdir $global->{config}->{'work-dir'} or die $!;
    }
    if (!-e $global->{config}->{'pod-dir'}) {
        mkdir $global->{config}->{'pod-dir'} or die $!;
    }

    # Get all the versions availible on the remote site
    my $tree;

    my $response = $global->{ua}->get( $global->{config}->{'remote-parent'} );
    if ($response->is_success) {
        $tree = HTML::TreeBuilder->new_from_content($response->decoded_content);
    } else {
        warn "Failed to connect to destination server (".$global->{config}->{'remote-parent'}.")";
        warn $response->status_line;
        $tree = HTML::TreeBuilder->new_from_content("<html></html>");
    }

    my @perl_versions;

    for (@{  $tree->extract_links('a')  }) {
        my ($link, $element, $attr, $tag) = @$_;
        if ($link =~ m@^.*perl-5\.(\d+)\.(\d+)\.tar\.gz$@ || $link =~ m@^.*perl-5\.(\d+)\.(\d+)\.tar\.gz\.(sha256)\.txt$@) {
            my ($major,$minor,$checksum) = ($1,$2,$3);
            # Skip anything that is not a stable release
            next if ($major % 2 != 0);
            # Anything before this the POD is to crap tastic to worry about, only bother with stable releases
            next if ($major < 6);
            # Add the complete version to perl_version array for speed later on
            push @perl_versions,[$major,$minor];

            if ($checksum) {
                $global->{perl}->{$major}->{$minor}->{$checksum}                = $link;
                $global->{perl}->{$major}->{$minor}->{'download_checksum'}      = join('/',$global->{config}->{'remote-parent'},$link);
                $global->{perl}->{$major}->{$minor}->{checksum}                 = $checksum;
            } else {
                my ($local_name) = $link =~ m#^(.*?)\.tar\.gz$#;
                $global->{perl}->{$major}->{$minor}->{rawfilename}          = $local_name;
                $global->{perl}->{$major}->{$minor}->{filename}             = $link;
                $global->{perl}->{$major}->{$minor}->{local_path}           = join('/',$global->{config}->{'work-dir'},$local_name);
                $global->{perl}->{$major}->{$minor}->{make_path}            = join('/',$global->{config}->{'work-dir'},$local_name,'Makefile.perldoc');
                $global->{perl}->{$major}->{$minor}->{state_path}           = join('/',$global->{config}->{'work-dir'},$local_name,'.state');

                # Just incase we ever get a remote-parent with no ending /, // is processed as / anyway.
                $global->{perl}->{$major}->{$minor}->{'download_tarball'}   = join('/',$global->{config}->{'remote-parent'},$link);

                # Set the state
                $global->{perl}->{$major}->{$minor}->{state} = {'stage'=>'new'};
                if (-e $global->{perl}->{$major}->{$minor}->{state_path}) {
                    $global->{perl}->{$major}->{$minor}->{state} = do {
                        local $/;

                        open(my $fh,'<',$global->{perl}->{$major}->{$minor}->{state_path});
                        my $json = <$fh>;
                        close($fh);

                        my $decoded_json;
                        try {
                            $decoded_json = $global->{js}->decode($json);
                        } catch {
                            $decoded_json = $global->{perl}->{$major}->{$minor}->{state};
                        };

                        $decoded_json;
                    }
                }
            }
        }
    }

    # For all those of state new or who's download was marked broken, download and setup the enviroment
    foreach (@perl_versions) {
        my ($major,$minor) = ($_->[0],$_->[1]);
        my $env = $global->{perl}->{$major}->{$minor};

        # If this was already extracted correctly, skip it
        if ( $env->{state}->{stage} =~ m/^(download_ok|env_.*|build_.*|pod_.*|done_.*)$/) {
            print "Download($major.$minor): Skipping ($1)\n";
            next;
        }
        else {
            $global->{rebuild} = 1;
        }

        # Generate requests for the files
        my @download = (
            { 
                type        => 'checksum',
                request     => HTTP::Request->new( GET => $env->{download_checksum} ),
                filename    => $env->{$env->{checksum}},
                local_path  => join('/',$global->{config}->{'work-dir'},$env->{$env->{checksum}})
            },
            {
                type        => 'tarball',
                request     => HTTP::Request->new( GET => $env->{download_tarball} ),
                filename    => $env->{filename},
                local_path  => join('/',$global->{config}->{'work-dir'},$env->{filename})
            },
        );

        # Do the checks for existence BEFORE we do the loop (BUG AVOIDANCE TODO)
        $download[0]->{exists} = (-e $download[0]->{local_path}) ? 1 : 0;
        $download[1]->{exists} = (-e $download[1]->{local_path}) ? 1 : 0;

        # Download the perl tarballs
        my $failure = 0;
        foreach my $req (@download) {
            my $local_path = $req->{local_path};
            my $res;

            if (!$req->{exists} || $req->{type} eq 'checksum')  {
                $res = $global->{ua}->request( $req->{request}, $local_path );
                print "Downloading to: '$local_path'\n";
            }

            if ( !$req->{exists} && (!$res || !$res->is_success) ) { 
                $failure = 1;
            }
            elsif ($req->{type} eq 'tarball') {
                my $local_fn = $env->{filename};
                # Check the sha against the download
                my $sha256_local = sha256_file_hex($req->{local_path});
                my $sha256_authoritive = do {
                    local $/;
                    open(my $fh,'<',$download[0]->{local_path});
                    my $read = <$fh>;
                    close($fh);
                    $read
                };
                if ($sha256_local eq $sha256_authoritive) {
                    print "Success downloading: $local_fn SHA256( MATCH $sha256_local )\n";
                    $global->{perl}->{$major}->{$minor}->{state}->{stage} = 'download_ok';
                } else {
                    print "Refusing to proceed with $local_fn SHA256( LOCAL: $sha256_local AUTHORITIVE: $sha256_authoritive )\n";
                    $failure = 1;
                }
            }
        }

        if ($failure) {
            $global->{perl}->{$major}->{$minor}->{state}->{stage} = 'download_bad';
            unlink @{[$download[0]->{local_path},$download[1]->{local_path}]};
        }

        # Extract those that passed checks 
        if ($env->{state}->{stage} eq 'download_ok') {
            my $local_fn = "work/".$env->{filename};
            print "Extracting for: $local_fn\n";
            $global->{tar}->setcwd($global->{config}->{'work-dir'});
            $global->{tar}->read($local_fn);
            $global->{tar}->extract();
            print "Extraction complete for: $local_fn\n";

            {
                my $tidy_path = $global->{perl}->{$major}->{$minor}->{local_path};
                $tidy_path =~ s#//#/#g;
                system('chmod','-R',"700",$tidy_path);
            }
        }
    }

    return 0;
}

package OpusVL::PerlDoc::Template;

use warnings;
use strict;


my $hints = {
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
};

sub new {
    my ($class) = @_;

    # Some private stuff for ourself
    my $self = {};

    # Go with god my son
    bless $self, $class;
    return $self;
}

sub hint {
    my ($self,$version) = @_;
    return $hints->{$version} // '';
}

sub makefile {
    return <<'EOF'
.PHONY: clean configure pod patch

perlversion = $(shell bin/perl -e 'printf "%vd", $$^V')
perlpatch = $(shell perl -MDevel::PatchPerl -e 'print Devel::PatchPerl->patch_source()')

install: build
	make -f Makefile install
build: configure
	export PERLFLAGS="-A libs=-lm -A libs=-ldl -A libs=-lc -A ldflags=-lm -A cflags=-lm -A ccflags=-lm"
	make -f Makefile
test: build
	make test

pod:
	rm -Rf ../output/$(perlversion)
	mkdir -p ../output/$(perlversion)
	perl ../../build-perldoc-html.pl -output-path ../output/$(perlversion) -perl bin/perl -version $(perlversion)
clean:
	make clean
configure:
	./Configure -des -Dprefix=.
patch:
	echo $(perlpatch)
EOF
}

1;