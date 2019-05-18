package Perldoc::Syntax;

use Data::Dumper;
use Perl::Tidy;
use Perldoc::Function;
use Storable qw/nstore retrieve/;
use FindBin qw/$Bin/;

our %cache;

sub highlight {
  my ($start_tag,$end_tag,$content,$linkpath) = @_;
#  warn "start($start_tag) content($content) end($end_tag) linkpath($linkpath)";
  return join('',$start_tag,$content,$end_tag);
#  warn Dumper(@_);

#  unless (defined $cache{join "\034",@_}) {
    $cache{join "\034",@_} = _highlight(@_);
#  }
  
  my $result = $cache{join "\034",@_};


  return $result;
 
#
# Appears to not be required?
#
 
  if ($result =~ m!^<pre class="verbatim">!) {
    $result =~ s!^<pre class="verbatim">!!;
    $result =~ s!</pre>$!!;
    my $output = '<div class="verbatim"><ol>';
    my @lines = split(/\r\n|\n/,$result);
    #if (@lines > 1) {
      foreach (@lines) {
        $output .= "<li>$_</li>";
      }
      $output .= '</ol></div>';
      return $output;
    #} else {
    #  return qq{<pre class="verbatim">$result</pre>};
    #}
  } else {
    return $result;
  }
}                     
  
sub _highlight {
  warn '_highlight';
  my ($start,$end,$txt,$linkpath) = @_;
  if ($txt !~ /\s/) {
    if ($txt =~ /^(-?\w+)/i) {
      my $function = $1;
      if (Perldoc::Function::exists($function)) {
        return qq($start<a class="l_k" href=").$linkpath.qq(functions/$function.html">$txt</a>$end);
      }
    }
    if ($core_modules{$txt}) {
      return qq($start<a class="l_w" href="$linkpath$core_modules{$txt}">$txt</a>$end);
    }
  }
  
  my $original_text = $txt; 
  #$txt =~ s/<.*?>//gs;
  #$txt =~ s/&lt;/</gs;
  #$txt =~ s/&gt;/>/gs;
  #$txt =~ s/&amp;/&/gs;
  
  my @perltidy_argv = qw/-html -pre/;
  my $result;
  my $perltidy_error;
  my $stderr;
  warn 'perltidy()';
  perltidy( source=>\$txt, destination=>\$result, argv=>\@perltidy_argv, errorfile=>\$perltidy_error, stderr=>'std.err' );

  unless ($perltidy_error) {
    warn 'pertidy_error()';
    $result =~ s!<pre class="verbatim">\n*!$start!;
    $result =~ s!\n*</pre>!$end!;
    $result =~ s|(http://[-a-z0-9~/\.+_?=\@:%]+(?!\.\s))|<a href="$1">$1</a>|gim;
    $result =~ s!<span class="k">(.*?)</span>!(Perldoc::Function::exists($1))?q(<a class="l_k" href=").$linkpath.qq(functions/$1.html">$1</a>):$1!sge;
    $txt =~ s!<span class="w">(.*?)</span>!($core_modules{$1})?qq(<a class="l_w" href="$linkpath$core_modules{$1}">$1</a>):$1!sge;
    return $result;
  } else {
    warn 'pertidy_success()';
    $original_text =~ s/&/&amp;/sg;
    $original_text =~ s/</&lt;/sg;
    $original_text =~ s/>/&gt;/sg;
    return "$start$original_text$end";
  }
}

1;
