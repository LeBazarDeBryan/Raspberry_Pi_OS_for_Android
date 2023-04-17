package TigerVNC::Config;

# Below is documentation for your module. You'd better edit it!
=pod

=head1 NAME

TigerVNC::Config - Configuration reader

=head1 SYNOPSIS

  use TigerVNC::Config;

  my $options = { wrapperMode => 'tigervncserver' };

  # Parse the system /etc/tigervnc/vncserver-config-defaults and the user
  # ~/.vnc/tigervnc.conf configuration file as well as processes the command line.
  &getConfig($options);
 
=head1 DESCRIPTION

This package reads the configuration for the B<Xtigervnc> and B<X0tigervnc> servers.

=cut

use strict;
use warnings;

use File::Spec;
use File::Path qw(mkpath);

use TigerVNC::OptionTie;
use TigerVNC::Common;

=pod

=head1 EXPORTS

=over

=item OPT_PARAM

=item OPT_CFGFILE

=item OPT_TIGERVNCSERVER

=item OPT_X0TIGERVNCSERVER

=item OPT_XTIGERVNC

=item OPT_X0TIGERVNC

=item getOptionParseTable

=item readConfigFile

=item usage

=item getConfig

=back

=cut

use Exporter qw(import);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
our @EXPORT = qw(
  OPT_PARAM
  OPT_CFGFILE
  OPT_TIGERVNCSERVER
  OPT_X0TIGERVNCSERVER
  OPT_XTIGERVNC
  OPT_X0TIGERVNC
  getOptionParseTable
  readConfigFile
  usage
  getConfig
);

our @EXPORT_OK = qw(
);

# This allows declaration
#
#   use UDNSC::ConfigParser ':all';
#
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = (
# 'all' => \@EXPORT_OK,
);

our $VERSION = '1.11-1';

#
# Set global constants
#

=pod

=head1 GLOBALS

=over 4

=item $SYSTEMCONFIGDIR

The system configuration directory for TigerVNC, i.e., I</etc/tigervnc>.

=cut

our $SYSTEMCONFIGDIR = "/etc/tigervnc";

=pod

=back

=head1 FUNCTIONS

=cut

###############################################################################
#
# getXDisplayDefaults uses xdpyinfo to find out the geometry, depth and pixel
# format of the current X display being used.  If successful, it sets the
# options as appropriate so that the X VNC server will use the same settings
# (minus an allowance for window manager decorations on the geometry).  Using
# the same depth and pixel format means that the VNC server won't have to
# translate pixels when the desktop is being viewed on this X display (for
# TrueColor displays anyway).
#

sub getXDisplayDefaults {
  my ($override, $getDefaultFrom) = @_;

  my (@lines, @matchlines, $defaultVisualId, $i);

  return if !defined $getDefaultFrom;

  my $xdpyinfo = &getCommand("xdpyinfo");
  {
    $getDefaultFrom =~ s/^-display\s+//;
    local $ENV{'DISPLAY'} = $getDefaultFrom;
    @lines = `$xdpyinfo 2>/dev/null`;
  }

  return if ($? != 0);

  @matchlines = grep(/dimensions/, @lines);
  if (@matchlines) {
    my ($width, $height) = ($matchlines[0] =~ /(\d+)x(\d+) pixels/);
    &{$override}('geometry', "${width}x${height}");
    &{$override}('wmDecorationAdjustment', 1);
  }

  @matchlines = grep(/default visual id/, @lines);
  if (@matchlines) {
    ($defaultVisualId) = ($matchlines[0] =~ /id:\s+(\S+)/);

    for ($i = 0; $i < @lines; $i++) {
      if ($lines[$i] =~ /^\s*visual id:\s+$defaultVisualId$/) {
        if (($lines[$i+1] !~ /TrueColor/) ||
            ($lines[$i+2] !~ /depth/) ||
            ($lines[$i+4] !~ /red, green, blue masks/)) {
          return;
        }
        last;
      }
    }

    return if ($i >= @lines);

    my ( $depth ) = ($lines[$i+2] =~ /depth:\s+(\d+)/);
    &{$override}('depth', "$depth");
    my ($red,$green,$blue)
        = ($lines[$i+4]
           =~ /masks:\s+0x([0-9a-f]+), 0x([0-9a-f]+), 0x([0-9a-f]+)/);

    $red = hex($red);
    $green = hex($green);
    $blue = hex($blue);

    if ($red > $blue) {
      $red = int(log($red) / log(2)) - int(log($green) / log(2));
      $green = int(log($green) / log(2)) - int(log($blue) / log(2));
      $blue = int(log($blue) / log(2)) + 1;
      &{$override}('pixelformat', "rgb$red$green$blue");
    } else {
      $blue = int(log($blue) / log(2)) - int(log($green) / log(2));
      $green = int(log($green) / log(2)) - int(log($red) / log(2));
      $red = int(log($red) / log(2)) + 1;
      &{$override}('pixelformat', "bgr$blue$green$red");
    }
  }
}

sub handleVNCStartupAuto {
  my ($vncStartup, $options) = @_;

  my $vncStartupAuto = $vncStartup;
  if (-f File::Spec->catfile($options->{'vncUserDir'}, "Xtigervnc-session")) {
    # A user provided Xtigervnc-session script exists => use it.
    $vncStartupAuto =
      File::Spec->catfile($options->{'vncUserDir'}, "Xtigervnc-session");
  } elsif (-f File::Spec->catfile($options->{'vncUserDir'}, "Xvnc-session")) {
    # This is deprecated rename it to Xtigervnc-session.
    if (rename
        File::Spec->catfile($options->{'vncUserDir'}, "Xvnc-session")
      , File::Spec->catfile($options->{'vncUserDir'}, "Xtigervnc-session")) {
      symlink "Xtigervnc-session"
        , File::Spec->catfile($options->{'vncUserDir'}, "Xvnc-session");
      # A user provided Xtigervnc-session script exists => use it.
      $vncStartupAuto =
        File::Spec->catfile($options->{'vncUserDir'}, "Xtigervnc-session");
    } else {
      # A user provided Xtigervnc-session script exists => use it.
      $vncStartupAuto =
        File::Spec->catfile($options->{'vncUserDir'}, "Xvnc-session");
    }
  } elsif (-f File::Spec->catfile($options->{'vncUserDir'}, "xstartup")) {
    # A user provided Xtigervnc-session script exists => use it.
    $vncStartupAuto =
      File::Spec->catfile($options->{'vncUserDir'}, "xstartup");
  }
  if (defined($options->{'vncStartup'}) && $options->{'vncStartup'} eq '__AUTO__') {
    # vncStartup was not defined by the user configuration in ~/.vnc/vnc.conf.
    $options->{'vncStartup'} = $vncStartupAuto;
  }
}

=pod

=over 4

=item getOptionParseTable

Get list of all options for a given wrapper mode, i.e., I<tigervncserver> or I<x0tigervncserver>, and mode of configuration, i.e., I<mandatory>, I<defaults>, I<user>, or I<cmdline>.

  my $options = { wrapperMode => 'tigervncserver' };

  foreach my $optionParseEntry (@{&getOptionParseTable($options, "cmdline")}) {
    my ($flags, $optname, $store) = @{$optionParseEntry};
    ...
  }

=cut

sub OPT_PARAM()            { return 1;  }
sub OPT_CFGFILE()          { return 2;  }
sub OPT_TIGERVNCSERVER()   { return 4;  }
sub OPT_X0TIGERVNCSERVER() { return 32; }
sub OPT_XTIGERVNC()        { return 8;  }
sub OPT_X0TIGERVNC()       { return 16; }

sub getOptionParseTable($$) {
  my ($options, $desc) = @_;

  my $override = sub($) {
    my ($name, $value) = @_;

    if ($desc eq 'mandatory' && defined $options->{'src'}->{$name} &&
        $value ne $options->{$name}) {
      my $configFile = File::Spec->catfile($SYSTEMCONFIGDIR,
        "vncserver-config-mandatory");
      my $v;
      if (!defined $value) {
        $v = 'undef';
      } elsif (ref($value) eq '') {
        $v = '"'.$value.'"';
      } elsif (ref($value) eq 'ARRAY') {
        $v = '"'.join('", "', @{$value}).'"';
      } else {
        die 'Oops, '.ref($value).' values not supported!';
      }
      if ($options->{'src'}->{$name} eq 'defaults') {
        print STDERR "$PROG: Warning: $configFile is overriding $name from defaults config to be $v!\n";
      } elsif ($options->{'src'}->{$name} eq 'user') {
        print STDERR "$PROG: Warning: $configFile is overriding $name form user config to be $v!\n";
      } elsif ($options->{'src'}->{$name} eq 'cmdline') {
        print STDERR "$PROG: Warning: $configFile is overriding $name from commandline to be $v!\n";
      }
    }
    $options->{$name} = $value;
    $options->{'src'}->{$name} = $desc;
  };

  my $server = $options->{'wrapperMode'} eq 'tigervncserver'
        ? 'Xtigervnc' : 'X0tigervnc';

  # Flag field in $optionParseTable
  # 1  => Case insensitive
  # 2  => Config file parameter
  # 4  => Command line option for tigervncserver
  # 32 => Command line option for x0tigervncserver
  # 8  => Command line option for Xtigervnc
  # 16 => Command line option for X0tigervnc

  my $storeGeometry;

  my @optionParseTable = (
#     [ flag, 'name=type'      => store        ],
      # Options for -help mode
      [36, 'help|h|?'          => 'help',
       "if specified, dumps this help message." ],
      # Options for -kill mode
      [36, 'kill'              => 'kill',
       "if provided, kill the specified VNC server of the user." ],
      [36, 'clean'             => 'clean',
       "if specified, the log files of the terminated VNC session will also be removed." ],
      # Options for -list mode
      [36, 'list'              => 'list',
       "if provided, all active VNC servers of the user are listed." ],
      [36, 'cleanstale'        => 'cleanstale',
       "if provided, clean up pid and lockfiles of stale VNC server instances of the user." ],
      # Options for -version mode
      [36, 'version'           => 'version',
       "dumps version information of underlying $server VNC server." ],
      # Options for both tigervncserver and x0tigervncserver
      [53, 'display=s'         => sub {
          if (@_ == 2) {
            my ($host, $nr);
            if ($options->{'wrapperMode'} eq 'tigervncserver') {
              die "Invalid display $_[1]!" unless
                $_[1] =~ m/^([^:]*)(?::(\d+(?:\.\d+)?|\*))?$/;
              ($host, $nr) = ($1, $2);
            } else {
              die "Invalid display $_[1]!" unless
                $_[1] =~ m/^:(\d+(?:\.\d+)?|\*)$/;
              ($host, $nr) = (undef, $1);
            }
            $host =~ s{\[([0-9a-fA-F:.]+)\]$}{$1} if defined $host;
            $nr   =~ s{\.\d+$}{}                  if defined $nr;
            &{$override}('display', $_[1]);
            if (($host//'') eq '' || $host eq $HOST || $host eq $HOSTFQDN) {
              &{$override}('displayHost', $HOSTFQDN);
              &{$override}('remote', undef);
            } elsif ($host eq "localhost") {
              &{$override}('displayHost', $HOSTFQDN);
              &{$override}('localhost', 1);
              &{$override}('remote', undef);
            } else {
              &{$override}('displayHost', $host);
              &{$override}('remote', 1);
            }
            if (defined $nr) {
              &{$override}('displayNumber', $nr);
            }
          } elsif (defined $options->{'display'}) {
            return $options->{'display'};
          } else {
            return undef;
          }
        },
       "specifies the X11 display to be used." ],
      [63, 'rfbport=i'         => 'rfbport',
       "provides the TCP port to be used for the RFB protocol." ],
      [63, 'localhost:b'       => 'localhost',
       "if enabled, VNC will only accept connections from localhost." ],
      [63, 'SecurityTypes=s'   => 'SecurityTypes',
       "specifies a comma list of security types to offer (None, VncAuth, Plain, TLSNone, TLSVnc, TLSPlain, X509None, X509Vnc, X509Plain). On default, offer only VncAuth." ],
      [63, 'PasswordFile|rfbauth=s' => 'vncPasswdFile',
       "specifies the password file for security types VncAuth, TLSVnc, and X509Vnc. On default, ~/.vnc/passwd is used." ],
      # Backward compatible command line option
      [36, 'passwd=s'          => 'vncPasswdFile' ],
      [63, 'PlainUsers=s'      => 'PlainUsers',
       "specifies the list of authorized users for the security types Plain, TLSPlain, and X509Plain." ],
      [63, 'PAMService|pam_service=s' => 'PAMService',
       "specifies the service name for PAM password validation that is used in case of security types Plain, TLSPlain, or X509Plain. On default, vnc is used if present otherwise tigervnc is used." ],
      [63, 'X509Key=s'         => 'X509Key',
       "denotes a X509 certificate key file (PEM format). This is used by the security types X509None, X509Vnc, and X509Plain." ],
      [63, 'X509Cert=s'        => 'X509Cert',
       "denotes the corresponding X509 certificate (PEM format)." ],
      [36, 'fg'                => 'fg',
       "if enabled, $PROG will stay in the foreground." ],
      [36, 'useold'            => 'useold',
       "if given, start a VNC server only if one is not already running." ],
      [36, 'verbose'           => 'verbose',
       "if specified, debugging output is enabled." ],
      [36, 'dry-run'           => 'dry-run',
       "if enabled, no real action is taken only a simulation of what would be done is performed." ],
      [36, 'I-KNOW-THIS-IS-INSECURE' => 'I-KNOW-THIS-IS-INSECURE' ],
      # Parameters for both Xtigervnc and X0tigervnc (case insensitive)
      [63, 'UseIPv4:b'         => 'UseIPv4' ],
      [63, 'UseIPv6:b'         => 'UseIPv6' ],
      [63, 'rfbunixpath=s'     => 'rfbunixpath' ],
      [63, 'rfbunixmode=s'     => 'rfbunixmode' ],
      [63, 'ClientWaitTimeMillis|rfbwait=i' => 'rfbwait' ],
      [63, 'AcceptCutText:b'   => 'AcceptCutText' ],
      [63, 'MaxCutText=i'      => 'MaxCutText' ],
      [63, 'SendCutText:b'     => 'SendCutText' ],
      [63, 'AcceptPointerEvents:b' => 'AcceptPointerEvents' ],
      [63, 'AcceptKeyEvents:b' => 'AcceptKeyEvents' ],
      [63, 'AcceptSetDesktopSize:b' => 'AcceptSetDesktopSize' ],
      [63, 'DisconnectClients:b' => 'DisconnectClients' ],
      [63, 'NeverShared:b'     => sub {
          if (@_ == 2) {
            if ($_[1] eq '' || $_[1] eq '1') {
              &{$override}('shared', 'never');
            } elsif ($options->{'shared'} eq 'never') {
              &{$override}('shared', undef);
            }
          } elsif (defined $options->{'shared'}) {
            return $options->{'shared'} eq 'never' ? 1 : 0;
          } else {
            return undef;
          }
        } ],
      [63, 'AlwaysShared:b'    => sub {
          if (@_ == 2) {
            if ($_[1] eq '' || $_[1] eq '1') {
              &{$override}('shared', 'always');
            } elsif ($options->{'shared'} eq 'always') {
              &{$override}('shared', undef);
            }
          } elsif (defined $options->{'shared'}) {
            return $options->{'shared'} eq 'always' ? 1 : 0;
          } else {
            return undef;
          }
        } ],
      [63, 'Password=s'        => 'Password' ],
      [63, 'Protocol3.3:b'     => 'Protocol3.3' ],
      [63, 'FrameRate=i'       => 'FrameRate' ],
      [63, 'CompareFB=s'       => 'CompareFB' ],
      [63, 'ZlibLevel=i'       => 'ZlibLevel' ],
      [63, 'ImprovedHextile:b' => 'ImprovedHextile' ],
      [63, 'GnuTLSPriority=s'  => 'GnuTLSPriority' ],
      [63, 'UseBlacklist:b'    => 'UseBlacklist' ],
      [63, 'BlacklistThreshold=i' => 'BlacklistThreshold' ],
      [63, 'BlacklistTimeout=i' => 'BlacklistTimeout' ],
      [63, 'IdleTimeout=i'     => 'IdleTimeout' ],
      [63, 'MaxDisconnectionTime=i' => 'MaxDisconnectionTime' ],
      [63, 'MaxConnectionTime=i' => 'MaxConnectionTime' ],
      [63, 'MaxIdleTime=i'     => 'MaxIdleTime' ],
      [63, 'QueryConnect:b'    => 'QueryConnect' ],
      [63, 'QueryConnectTimeout=i' => 'QueryConnectTimeout' ],
      [63, 'Log=s'             => 'Log' ],
      [63, 'RemapKeys=s'       => 'RemapKeys' ],
      [63, 'RawKeyboard:b'     => 'RawKeyboard' ],
      # Options only for tigervncserver
      [14, 'geometry=s'        => sub {
          if (@_ == 2) {
            my $geometry = $_[1] // "undef";
            unless ($geometry =~ /^(\d+)x(\d+)$/) {
              die "Invalid geometry $_[1]!";
            }
            $options->{'wmDecorationAdjustment'} = undef;
            &{$override}('geometry', $_[1]);
          } elsif (defined $options->{'geometry'}) {
            $options->{'geometry'} =~ m/^(\d+)x(\d+)$/;
            my ($width, $height) = ($1, $2);
            if ($options->{'wmDecorationAdjustment'}) {
              $options->{'wmDecoration'} =~ /^(\d+)x(\d+)$/;
              my ($wmDecorationWidth, $wmDecorationHeight) = ($1, $2);
              $width  -= $wmDecorationWidth;
              $height -= $wmDecorationHeight;
            }
            $width  = 4 if $width  < 4;
            $height = 2 if $height < 2;
            # Round up to multiples of 4, respectively, 2 for width and height.
            $width  = int(($width +3)/4)*4;
            $height = int(($height+1)/2)*2;
            return "${width}x${height}";
          } else {
            return undef;
          }
        },
        "specifies the desktop geometry, e.g., <width>x<height>." ],
      [ 6, 'wmDecoration=s'    => sub {
          if (@_ == 2) {
            if (defined $_[1]) {
              my $wmDecoration = $_[1] // "undef";
              unless ($_[1] =~ m/^(\d+)x(\d+)$/) {
                die "Invalid wmDecoration $_[1]!";
              }
              $options->{'wmDecorationAdjustment'} = 1;
            } else {
              $options->{'wmDecorationAdjustment'} = undef;
            }
            &{$override}('wmDecoration', $_[1]);
          } else {
            return $options->{'wmDecoration'};
          }
        },
        "if specified, shrinks the geometry by the given <width>x<height> value." ],
      [ 4, 'xdisplaydefaults'  => sub {
          if (@_ == 2) {
            &getXDisplayDefaults($override,
              $ENV{DISPLAY} // $options->{'getDefaultFrom'});
          } else {
            return undef;
          }
        },
       "if given, obtain the geometry and pixelformat from ".(defined $ENV{DISPLAY}
         ? "the $ENV{DISPLAY} X server."
         : "a running X server.") ],
      [ 4, 'xstartup:s'        => sub {
          if (@_ == 2) {
            if ($_[1] eq '') {
              &{$override}('vncStartup', '__AUTO__');
            } else {
              &{$override}('vncStartup', $_[1]);
            }
          } else {
            return $options->{'vncStartup'};
          }
        },
       "specifies the script to start an X11 session for Xtigervnc." ],
      [ 4, 'noxstartup'        => sub {
          if (@_ == 2) {
            &{$override}('vncStartup', undef);
          } elsif (defined $options->{'src'}->{'vncStartup'}) {
            return !defined $options->{'vncStartup'};
          } else {
            return undef;
          }
        },
       "disables X session startup." ],
      [15, 'desktop=s'         => 'desktopName',
       "specifies the VNC desktop name." ],
      # Backward compatible command line option
      [ 4, 'name=s'            => 'desktopName' ],
      [14, 'depth=i'           => sub {
          if (@_ == 2) {
            if (defined $_[1]) {
              my $depth = int($_[1]);
              if ($depth != 16 && $depth != 24 && $depth != 32) {
                die "Invalid depth $depth must be one of 16, 24, or 32!";
              }
              if (defined $options->{'pixelformat'}) {
                $options->{'pixelformat'} =~ m/^(?:rgb|bgr)(\d)(\d)(\d)$/;
                if ($depth < $1+$2+$3) {
                  &{$override}('pixelformat', undef);
                }
              }
            }
            &{$override}('depth', $_[1]);
          } else {
            return $options->{'depth'};
          }
        },
        "specifies the bit depth of the desktop, e.g., 16, 24, or 32." ],
      [14, 'pixelformat=s'     => sub {
          if (@_ == 2) {
            if (defined $_[1]) {
              unless ($_[1] =~ m/^(?:rgb|bgr)(\d)(\d)(\d)$/) {
                die "Invalid pixelformat $_[1]!";
              }
              my $depth = $1+$2+$3;
              if ($depth != 16 && $depth != 24 && $depth != 32) {
                die "Invalid pixelformat $_[1]!";
              }
              if ($options->{'depth'} < $depth) {
                &{$override}('depth', undef);
              }
            }
            &{$override}('pixelformat', $_[1]);
          } else {
            return $options->{'pixelformat'};
          }
        },
        "defines the X11 server pixel format. Valid values are rgb888, rgb565, bgr888, or bgr565." ],
      [ 4, 'autokill:b'        => 'autokill',
       "if enabled -- the default -- the VNC server is killed after its X session has terminated." ],
      [14, 'fp=s'              => 'fontPath',
       "specifies a colon separated list of font locations." ],
      [ 6, 'session=s'         => sub {
          if (@_ == 2) {
            my ($sn, $snt);
            if (!defined($_[1]) || $_[1] eq '') {
              $sn = $snt = [];
            } elsif (ref($_[1]) eq 'ARRAY') {
              $sn = $snt = $_[1];
            } elsif (ref($_[1]) eq '') {
              $sn = $snt = [split(qr{\s+}, $_[1])];
              unless ($options->{'remote'}) {
                my $sessionCommand = loadXSession($_[1]) unless $_[1] =~ m{/};
                my $found = 0;
                if (defined $sessionCommand) {
                  $snt = [$sessionCommand];
                  $found = 1;
                } elsif (@{$sn} > 0) {
                  if ($sn->[0] =~ m{/}) {
                    my $fqcmd = File::Spec->rel2abs($sn->[0]);
                    if (-x $fqcmd) {
                      $found = 1;
                      $snt->[0] = $fqcmd;
                    }
                  } else {
                    foreach my $dir (split(/:/,$ENV{PATH})) {
                      my $fqcmd = File::Spec->catfile($dir, $sn->[0]);
                      if (-x $fqcmd) {
                        $found = 1;
                        $snt->[0] = $fqcmd;
                        last;
                      }
                    }
                  }
                }
                unless ($found) {
                  print STDERR "$PROG: Warning: No X session desktop file or command for $_[1]\n";
                }
              }
            } else {
              die "Option $_[0] must be set to a string or array reference!";
            }
            &{$override}('session-orig', $sn);
            $options->{'session'} = $snt;
          } else {
            return $options->{'session-orig'};
          }
        },
       "specifies the X11 session to start with either a command or a session name." ],
      # Arguments from Xtigervnc (case sensitive)
      [14, 'auth=s'            => 'xauthorityFile' ],
      # -inetd is not handled
      [14, 'interface=s'       => sub {
          if (@_ == 2) {
            &{$override}('interface', $_[1]);
            &{$override}('localhost', undef);
          } else {
            return $options->{'interface'};
          }
        } ],
      # Parameters for Xtigervnc (case insensitive)
      [15, 'AvoidShiftNumLock:b' => 'AvoidShiftNumLock' ],
      [15, 'AllowOverride=s'   => 'AllowOverride' ],
      [15, 'SendPrimary:b'     => 'SendPrimary' ],
      # Parameters for X0tigervnc (case insensitive)
      [49, 'Geometry=s'        => $storeGeometry = sub {
          if (@_ == 2) {
            my $Geometry = $_[1] // "undef";
            unless ($Geometry =~ /^(\d+)x(\d+)(?:([+-]\d+)([+-]\d+))?$/) {
              die "Invalid $_[0] $_[1]!";
            }
            &{$override}('Geometry', $_[1]);
          } else {
            return $options->{'Geometry'};
          }
        },
        "specifies the screen area that will be shown to VNC clients. The format is widthxheight+xoffset+yoffset, where `+' signs can be replaced with `-' signs to specify offsets from the right and/or from the bottom of the screen. Offsets are optional, +0+0 is assumed by default (top left corner). If the argument is  empty, full screen is shown to VNC clients (this is the default)." ],
      [49, 'HostsFile=s'       => 'HostsFile' ],
      [49, 'MaxProcessorUsage=i' => 'MaxProcessorUsage' ],
      [49, 'PollingCycle=i'    => 'PollingCycle' ],
      [49, 'UseSHM:b'          => 'UseSHM' ],
      # Config file stuff
      [ 2, 'sslAutoGenCertCommand=s' => 'sslAutoGenCertCommand' ],
      [ 2, 'vncUserDir=s'      => 'vncUserDir' ],
      [ 2, 'vncStartup=s'      => 'vncStartup' ],
      [ 2, 'xauthorityFile=s'  => 'xauthorityFile' ],
      [ 2, 'getDefaultFrom=s'  => 'getDefaultFrom' ],
      [ 2, 'scrapingGeometry=s'=> $storeGeometry ],
      # Backward compatible configuration file option for desktop
      [ 2, 'desktopName=s'     => 'desktopName' ],
      # Backward compatible configuration file optionfor PasswordFile
      [ 2, 'vncPasswdFile=s'   => 'vncPasswdFile' ],
      # Backward compatible configuration file option for fp
      [ 2, 'fontPath=s'        => 'fontPath' ],
    );

  my $optionParseTable = [];
  foreach my $optionParseEntry (@optionParseTable) {
    my ($flags, $optname, $store, $help) = @{$optionParseEntry};
    if (@{$optionParseEntry} < 3 || @{$optionParseEntry} > 4 ||
        (ref($store) ne '' && ref($store) ne 'CODE')) {
#     print $#{$optionParseEntry}, "\n";
#     print ref($optionParseEntry->[2]), "\n";
      die "Oops, internal error: Wrong optioneParseEntry!";
    }
    my $valueVerifyer = undef;
    if ($optname =~ m/:b$/) {
      $valueVerifyer = sub {
        if ($_[1] eq '' || $_[1] eq '1' || $_[1] eq 'yes' || $_[1] eq 'true') {
          return 1;
        } elsif ($_[1] eq '0' || $_[1] eq 'no' || $_[1] eq 'false') {
          return 0;
        } else {
          die "Option $_[0] can only be set to true or false!";
        }
      }
    } elsif ($optname =~ m/=i$/) {
      $valueVerifyer = sub { $_[1] };
    } elsif ($optname =~ m/[=:]s$/) {
      $valueVerifyer = sub { $_[1] };
    } elsif ($optname =~ m/[=:!+]/) {
      die "Oops, internal error: Can't parse $optname format!";
    } else {
      $valueVerifyer = sub {
        die "Option $_[0] can only be set to 1!" unless $_[1] eq 1;
        $_[1]
      };
    }
    if (ref($store) eq '') {
      push @{$optionParseTable}, [
          $flags,
          $optname,
          sub {
            if (@_ == 2) {
#             print STDERR $_[0], " <= ", $_[1]//"undef","\n";
              &{$override}($store, &{$valueVerifyer}(@_));
              return undef;
            } else {
              my $value = $options->{$store};
#             print STDERR $_[0], " => ", $value//"undef","\n";
              return $value;
            }
          },
          $help
        ];
    } else { # ref($store) eq 'CODE'
      push @{$optionParseTable}, [
          $flags,
          $optname,
          sub {
            if (@_ == 2) {
#             print STDERR $_[0], " <= ", $_[1]//"undef","\n";
              &{$valueVerifyer}(@_);
              &{$store}($_[0], &{$valueVerifyer}(@_));
              return undef;
            } else {
              my $value = &{$store}(@_);
#             print STDERR $_[0], " => ", $value//"undef","\n";
              return $value;
            }
          },
          $help
        ];
    }
  }

  return $optionParseTable;
}

=pod

=item readConfigFile

This function reads the configuration file and updates the options hash with the values from the read file.

  my $options = { wrapperMode => 'tigervncserver' };

  TigerVNC::Config::readConfig($options, "defaults",
    "/etc/tigervnc/vncserver-config-defaults");

=cut

sub readConfigFile($$) {
  my ($options, $desc) = @_;
  my ($configFile, $textConfig);

  if ($desc eq 'mandatory') {
    $configFile = File::Spec->catfile($SYSTEMCONFIGDIR,
      "vncserver-config-mandatory");
  } elsif ($desc eq 'defaults') {
    $configFile = File::Spec->catfile($SYSTEMCONFIGDIR,
      "vncserver-config-defaults");
  } elsif ($desc eq 'user') {
    if (-f File::Spec->catfile($options->{'vncUserDir'}, "tigervnc.conf")) {
      # User provided TigerVNC configuration found
      $configFile = File::Spec->catfile($options->{'vncUserDir'}, "tigervnc.conf");
    } elsif (-f File::Spec->catfile($options->{'vncUserDir'}, "vnc.conf")) {
      # This is deprecated rename it to tigervnc.conf
      if (rename
          File::Spec->catfile($options->{'vncUserDir'}, "vnc.conf")
        , File::Spec->catfile($options->{'vncUserDir'}, "tigervnc.conf")) {
        symlink "tigervnc.conf"
          , File::Spec->catfile($options->{'vncUserDir'}, "vnc.conf");
        # User provided TigerVNC configuration found
        $configFile = File::Spec->catfile($options->{'vncUserDir'}, "tigervnc.conf");
      } else {
        # User provided TigerVNC configuration found
        $configFile = File::Spec->catfile($options->{'vncUserDir'}, "vnc.conf");
      }
    } elsif (-f File::Spec->catfile($options->{'vncUserDir'}, "config")) {
      # User provided TigerVNC configuration found
      $configFile = File::Spec->catfile($options->{'vncUserDir'}, "config");
      $textConfig = 1;
    }
  } else {
    die "Oops, $desc config file not known!";
  }

  return unless defined $configFile and -f $configFile;

  if ($textConfig) {
    my $configFileFh = IO::File->new($configFile, "r");

    my %lowCase;

    foreach my $optionParseEntry (@{&getOptionParseTable($options, $desc)}) {
      my ($flags, $optname, $store) = @{$optionParseEntry};
      next unless $flags & &OPT_CFGFILE;

      $optname =~ m/^([^:=]*)/;
      $optname = $1;

      foreach my $name (split(/\|/, $optname)) {
        $lowCase{lc($name)} = sub { &{$store}($name, @_) };
      }
    }
    while (my $line = <$configFileFh>) {
      chomp $line; $line =~ s/#.*$//;
      next if $line =~ /^\s*$/;
      if ($line =~ /^\s*(\w+)\s*=\s*(.*)$/) {
        my ($k, $v) = ($1, $2);
        chomp $v;
        if (defined $lowCase{lc($k)}) {
          &{$lowCase{lc($k)}}($v);
        } else {
          $options->{'vncServerExtraArgs'} = [grep {
              $_->{'name'} ne $k
            } @{$options->{'vncServerExtraArgs'}}];
          push @{$options->{'vncServerExtraArgs'}}, {
              name => $k,
              src  => $desc,
              args => [ "-$k", $v ]
            };
        }
      } elsif ($line =~ m/^\s*(\w+)\s*$/) {
        my ($k) = ($1);
        if (defined $lowCase{lc($k)}) {
          &{$lowCase{lc($k)}}(1);
        } else {
          $options->{'vncServerExtraArgs'} = [grep {
              $_->{'name'} ne $k
            } @{$options->{'vncServerExtraArgs'}}];
          push @{$options->{'vncServerExtraArgs'}}, {
              name => $k,
              src  => $desc,
              args => [ "-$k" ]
            };
        }
      } else {
        print STDERR "$PROG: Warning: Can't parse '$line' from config file $configFile!\n";
      }
    }
    $configFileFh->close();
  } else {
    # Clean config package before loading new config
    foreach my $key (keys %{config::}) {
      delete ${config::}{$key};
    }

    $config::wrapperMode = $options->{'wrapperMode'};

    my %tiedNoCase;

    foreach my $optionParseEntry (@{&getOptionParseTable($options, $desc)}) {
      my ($flags, $optname, $store) = @{$optionParseEntry};
      next unless $flags & &OPT_CFGFILE;

      $optname =~ m/^([^:=]*)/;
      $optname = $1;

  #   print STDERR "==> $optname <==\n";
      foreach my $name (split(/\|/, $optname)) {
        $name =~ s{[^a-zA-Z0-9_]}{_}g;
  #     print STDERR $name, "\n";
        no strict 'refs';
        tie ${"config::$name"}, 'TigerVNC::OptionTie', sub { &{$store}($name, @_) };
        $tiedNoCase{lc($name)} = $name;
      }
    }

  # print STDERR "readConfigFile $desc $configFile\n";

    $@ = undef;
    {
      package config;
      do $configFile;
    }
    if ($@) {
      print STDERR "$PROG: Error parsing config file $configFile: $@";
      exit -1;
    }

    foreach my $key (keys %{config::}) {
      next if $key eq 'wrapperMode';
      if (my $name = $tiedNoCase{lc($key)}) {
        next if $name eq $key;
        print STDERR "$PROG: Warning: $key option must be $name in config file $configFile!\n";
        next;
      }
      my $value = ${${config::}{$key}};
      $options->{'vncServerExtraArgs'} = [grep {
          $_->{'name'} ne $key
        } @{$options->{'vncServerExtraArgs'}}];
      if (defined $value) {
        push @{$options->{'vncServerExtraArgs'}}, {
            name => $key,
            src  => $desc,
            args => [ "-$key", $value ]
          };
      }
    }
  }
}

#
# Load a session desktop file
#
sub loadXSession {
  my ($name) = @_;
  my ($file, $found_group, %session);

  $file = "/usr/share/xsessions/$name.desktop";

  if (!-f $file) {
    return;
  }

  my $fh;
  if (!open($fh, $file)) {
    warn "Could not open session desktop file $file: $!";
    return;
  }

  $found_group = 0;
  while (my $line = <$fh>) {
    next if $line =~ /^#/;
    next if $line =~ /^\s*$/;

    chomp $line;

    if (!$found_group) {
      next if $line ne "[Desktop Entry]";
      $found_group = 1;
      next;
    } else {
      last if $line =~ /^\[/;
    }

    my ($key, $value) = $line =~ /^\s*([]A-Za-z0-9_@\-\[]+)\s*=\s*(.*)$/;
    if (!$key) {
      warn "Invalid session desktop file $file";
      close($fh);
      return;
    }

    $value =~ s/\\s/ /g;
    $value =~ s/\\n/\n/g;
    $value =~ s/\\t/\t/g;
    $value =~ s/\\r/\r/g;
    $value =~ s/\\\\/\\/g;

    $session{$key} = $value;
#   print STDERR "$key => $value\n";
  }

  close($fh);

  unless (defined $session{'Exec'}) {
    warn "Invalid session desktop file $file does not contain a command to start the session!";
    close($fh);
    return;
  }

  return $session{'Exec'};
}

sub parseCmdLine {
  my ($options) = @_;
  my $rc = 1;

  my $activeFlag = $options->{'wrapperMode'} eq 'tigervncserver'
    ? &OPT_TIGERVNCSERVER : &OPT_X0TIGERVNCSERVER;

  my (%opts, %pars, $sessionStore, $displayStore);
  my (%noOpts, %noPars);
  foreach my $optionParseEntry (@{&getOptionParseTable($options, "cmdline")}) {
    my ($flags, $optname, $store) = @{$optionParseEntry};
    my $opttype = '';
    if ($optname =~ m/^([^:=]*)([:=][bis])$/) {
      $optname = $1;
      $opttype = $2;
    }
    if ($flags & $activeFlag) {
      if ($optname eq 'session') {
        $sessionStore = $store;
        next; # Session is a pseudo option, it's given via -- <session>.
      }
      if ($optname eq 'display') {
        $displayStore = $store;
      }
      foreach my $name (split(/\|/, $optname)) {
        if ($flags & &OPT_PARAM) {
          $pars{lc($name)} = [ $name.$opttype, $store ];
        } else {
          $opts{$name} = [ $name.$opttype, $store ];
        }
      }
    } else {
      foreach my $name (split(/\|/, $optname)) {
        if ($flags & &OPT_PARAM) {
          $noPars{lc($name)} = 1;
        } else {
          $noOpts{$name} = 1;
        }
      }
    }
  }
  # Command line parsing
  {
    my $pendingExtraArg = undef;
    while (@ARGV) {
      my $arg = shift @ARGV;
      my $opt = undef;
      my $par = undef;
      my $val = undef;

      if ($arg eq '--') {
        unless (defined $sessionStore) {
          print STDERR "$PROG: No session arguments allowed!\n\n";
          $rc = 0;
          last;
        }
        my $sn  = [@ARGV]; @ARGV = ();
        $sn = $sn->[0] if @{$sn} == 1;
        unless (eval { &{$sessionStore}('session', $sn); 1 }) {
          my $errorText = $@;
          $errorText =~ s/ at .* line \d+\.$//;
          chomp $errorText;
          print STDERR "$PROG: Invalid session: $errorText\n\n";
          $rc = 0;
          last;
        }
        next;
      } elsif (($arg =~ /^((?:[^-:@=.0-9][\w.-]+@)?(?:\d+\.\d+\.\d+\.\d+|\[[0-9a-fA-F:.]+\]|[^-:@=.0-9][^=:@]*))?(?::(\d+(?:\.\d+)?|\*))?$/) &&
          defined($displayStore) &&
          eval { &{$displayStore}('display', $arg); 1 }) {
#       print STDERR "==> $arg <==\n";
        undef $pendingExtraArg;
        next;
      } elsif ($arg =~ m/^(-([a-zA-Z]))=(.*)$/) {
        $arg = $1;
        $opt = $2;
        $val = $3;
      } elsif ($arg =~ m/^-([a-zA-Z])$/) {
        $opt = $1;
      } elsif ($arg =~ m/^(--?([a-zA-Z][^=]+))=(.*)$/) {
        $arg = $1;
        $opt = $par = $2;
        $val = $3;
      } elsif ($arg =~ m/^--?([a-zA-Z][^=]+)$/) {
        $opt = $par = $1;
      } elsif ($arg =~ m/^([a-zA-Z][^=]+)=(.*)$/) {
        $par = $1;
        $val = $2;
      } elsif (defined $pendingExtraArg) {
        push @{$pendingExtraArg->{'args'}}, $arg;
        undef $pendingExtraArg;
        next;
      } else {
        $rc = 0;
        print STDERR "$PROG: Option $arg: Unrecognized!\n\n";
        last;
      }
      my $optInfo = $pars{lc($par)} // $opts{$opt//'undef'};
      $opt = $par;
      if (defined $optInfo) {
        if ($optInfo->[0] =~ m/=/) {
          $val = shift @ARGV unless defined $val;
          unless (defined $val) {
            $rc = 0;
            print STDERR "$PROG: Option $arg: Missing option value!\n\n";
            last;
          }
        } elsif ($optInfo->[0] =~ m/:b$/) {
          if (@ARGV && !defined $val) {
            $val = shift @ARGV;
            unless ($val =~ m/^(0|1|no|yes|false|true)$/) {
              unshift @ARGV, $val;
              undef $val;
            }
          }
        } elsif ($optInfo->[0] =~ m/:s$/) {
          if (@ARGV && !defined $val) {
            $val = shift @ARGV;
            if ($val =~ m/^-/) {
              unshift @ARGV, $val;
              undef $val;
            }
          }
        } else {
          if (defined $val) {
            $rc = 0;
            print STDERR "$PROG: Option $arg: Does not take an option value!\n\n";
            last;
          }
          $val = 1;
        }
        unless (eval { &{$optInfo->[1]}($opt, $val//""); 1 }) {
          my $errorText = $@;
          $errorText =~ s/ at .* line \d+\.$//;
          chomp $errorText;
          print STDERR "$PROG: Option $arg: $errorText\n\n";
          $rc = 0;
          last;
        }
        undef $pendingExtraArg;
      } elsif (defined($noPars{lc($par)} // $noOpts{$opt//'undef'})) {
        $rc = 0;
        print STDERR "$PROG: Option $arg: Unrecognized!\n\n";
        last;
      } else {
        $options->{'vncServerExtraArgs'} = [grep {
            $_->{'name'} ne $opt
          } @{$options->{'vncServerExtraArgs'}}];
        $pendingExtraArg = {
            name => $opt,
            src  => 'cmdline',
            args => [ $arg ]
          };
        push @{$options->{'vncServerExtraArgs'}}, $pendingExtraArg;
        undef $pendingExtraArg if defined $val;
      }
    }
  }
  return $rc;
}

sub lineBreakText($$) {
  my ($fh, $indent, $text) = @_;

  foreach my $block (split /\n/, $text) {
    my $line = undef;
    foreach my $word (split /\s+/, $block) {
      if (!defined $line) {
        $line = $indent . $word;
        $indent = " "x length($indent);
      } elsif (length($line)+length($word)+1 <= $COLUMNS) {
        $line .= " " . $word;
      } else {
        print $fh $line, "\n";
        $line = $indent . $word;
      }
    }
    if (defined $line) {
      print $fh $line, "\n";
    } else {
      print $fh $indent, "\n";
    }
  }
}

=pod

=item usage

Dump command line help to STDOUT or STDERR.

=cut

sub usage {
  my ($options) = @_;

  my %opts;
  my @opts;

  my $activeFlag = $options->{'wrapperMode'} eq 'tigervncserver'
    ? &OPT_TIGERVNCSERVER : &OPT_X0TIGERVNCSERVER;

  foreach my $optionParseEntry (@{&getOptionParseTable($options, "cmdline")}) {
    my ($flags, $optname, $store, $help) = @{$optionParseEntry};
    next unless $flags & $activeFlag;
    my $defname = $optname;
    my $opttype = '';
    my $optval  = '';
    if ($optname =~ m/^(([^|:=]*)(?:|[^:=]*)?)([:=][bis])?$/) {
      $optname = $1;
      $defname = $2;
      $opttype = $3 if defined $3;
    }
    if ($opttype =~ m/^[:=]b$/) {
      $optval = 'yes|no'
    } elsif ($opttype =~ m/^[:=]i$/) {
      $optval = '<number>';
    } elsif ($opttype ne '') {
      $optval = '<value>';
    }
    if ($opttype =~ m/^:/) {
      $optval = ' ['.$optval.']';
    } elsif ($optval ne '') {
      $optval = ' '.$optval;
    }
    $opts{$defname} = [];
    push @opts, $defname;
    foreach my $name (split(/\|/, $optname)) {
      my $opt = $defname =~ m/^(?:kill|list|help)$/
        ? " -$name$optval"
        : "[-$name$optval]";

      if ($name eq $defname) {
        push @{$opts{$defname}}, {
            opt   => $opt,
            flags => $flags,
            help  => $help
          };
      } else {
        push @{$opts{$defname}}, {
            opt   => $opt,
            flags => $flags,
            help  => "is an alias for $defname."
          };
      }
    }
  }

  my $fh = \*STDOUT;
  $fh = \*STDERR if $options->{'usageError'};

  {
#   my @optsNoHelp = grep { !defined $opts{$_}->[0]->{'help'} } @opts;
#   my @optsHelp   = grep {  defined $opts{$_}->[0]->{'help'} } @opts;
#   @opts = (@optsHelp, sort { lc($a) cmp lc($b) } @optsNoHelp);
    @opts = grep { defined $opts{$_}->[0]->{'help'} } @opts;
    if ($options->{'wrapperMode'} eq 'tigervncserver') {
      $opts{'Xtigervnc'} = [
          { opt   => '[Xtigervnc options...]',
            flags => &OPT_XTIGERVNC | &OPT_TIGERVNCSERVER,
            help  => 'For details, see Xtigervnc(1).' }
        ];
      push @opts, 'Xtigervnc';
    } else {
      $opts{'X0tigervnc'} = [
          { opt   => '[X0tigervnc options...]',
            flags => &OPT_X0TIGERVNC | &OPT_X0TIGERVNCSERVER,
            help  => 'For details, see X0tigervnc(1).' }
        ];
      push @opts, 'X0tigervnc';
    }
  }
  if (defined $opts{'display'}) {
    $opts{'display'} = [
        { opt   => '[:<number>]',
          flags => $opts{'display'}->[0]->{'flags'},
          help  => $opts{'display'}->[0]->{'help'} },
        { opt  => $opts{'display'}->[0]->{'opt'},
          flags => $opts{'display'}->[0]->{'flags'},
          help => 'is an alias for :<number>.' },
      ];
  }
  if (defined $opts{'session'}) {
    $opts{'session'} = [
        { opt   => '[-- <session>]',
          flags => $opts{'session'}->[0]->{'flags'},
          help  => $opts{'session'}->[0]->{'help'} },
      ];
    @opts = ((grep { $_ ne 'session' } @opts), 'session');
  }

  my $optLen = 0;
  foreach my $opt (@opts) {
    foreach my $entry (@{$opts{$opt}}) {
      my $opt = $entry->{'opt'};
      $optLen = length($opt) if $optLen < length($opt);
    }
  }
  $optLen += 1;

  my $usageOptionDumping = sub {
    foreach my $opt (@_) {
      foreach my $entry (@{$opts{$opt}}) {
        my $help = $entry->{'help'};
#       unless (defined $help) {
#         if ($options->{'wrapperMode'} eq 'tigervncserver') {
#           if ($entry->{'flags'} & &OPT_XTIGERVNC) {
#             $help = "is an Xtigervnc option. For details, see Xtigervnc(1)."
#           }
#         } else {
#           if ($entry->{'flags'} & &OPT_X0TIGERVNC) {
#             $help = "is an X0tigervnc option. For details, see X0tigervnc(1)."
#           }
#         }
#       }
        if ($COLUMNS > 40 + 4 + ${optLen}) {
          my $indent = sprintf "    %-${optLen}s", $entry->{'opt'};
          &lineBreakText($fh, $indent, $help);
        } else {
          printf $fh "    %-${optLen}s\n", $entry->{'opt'};
          &lineBreakText($fh, "      ", $help);
        }
      }
    }
  };

  print $fh "$PROG usage:\n\n";
  {
    &lineBreakText($fh, "  ", "Help can be found in $PROG(1), or via usage of");
    &{$usageOptionDumping}(qw(help));
  }
  {
    my @dumpOpts = grep {
        !($_ =~ m/^(?:help|kill|clean|list|cleanstale|version|I-KNOW-THIS-IS-INSECURE)$/)
      } @opts;
    if ($options->{'wrapperMode'} eq 'tigervncserver') {
      &lineBreakText($fh, "  ", "\nTo start a VNC server use $PROG [options] [-- session]");
    } else {
      &lineBreakText($fh, "  ", "\nTo start a VNC server use $PROG [options]");
    }
    &{$usageOptionDumping}(@dumpOpts);
  }
  {
    &lineBreakText($fh, "  ", "\nTo list all active VNC servers of the user use $PROG");
    &{$usageOptionDumping}(qw(list display rfbport cleanstale));
  }
  {
    &lineBreakText($fh, "  ", "\nTo kill a VNC server use $PROG");
    &{$usageOptionDumping}(qw(kill display rfbport dry-run verbose clean));
  }
  {
    &lineBreakText($fh, "  ", "\nTo dump version information use $PROG");
    &{$usageOptionDumping}(qw(version));
  }
  if ($options->{'wrapperMode'} eq 'tigervncserver') {
    &lineBreakText($fh, "  ", "\n\nFor further help, consult the $PROG(1) and Xtigervnc(1) manual pages.");
  } else {
    &lineBreakText($fh, "  ", "\n\nFor further help, consult the $PROG(1) and X0tigervnc(1) manual pages.");
  }
}

=pod

=item getConfig

This function parses the system I</etc/tigervnc/vncserver-config-defaults> and the user I<~/.vnc/tigervnc.conf> configuration file as well as processes the command line to return an options hash.

  my $options = { wrapperMode => 'tigervncserver' };

  # Parse the system /etc/tigervnc/vncserver-config-defaults and the user
  # ~/.vnc/tigervnc.conf configuration file as well as processes the command line.
  &getConfig($options);

=cut

sub getConfig {
  my $opts;
  if (@_ == 1 && ref($_[0]) eq 'HASH') {
    $opts= $_[0];
  } else {
    $opts= { @_ };
  }

  #
  # Global options. You may want to configure some of these for your site.
  # Use /etc/tigervnc/vncserver-config-defaults and ~/.vnc/tigervnc.conf for
  # this purpose.
  #
  my %options = (
# Values specified via the command line
      autokill                  => 1,
      fg                        => 0,
      useold                    => 0,
      'dry-run'                 => 0,
# Values that are documented in /etc/tigervnc/vncserver-config-*
## Values declared as system values in /etc/tigervnc/vncserver-config-*
      fontPath                  => undef,
      PAMService                =>
        undef, # Use vnc if /etc/pam.d/vnc exists. Otherwise,
               # use our own /etc/pam.d/tigervnc as fallback.
      sslAutoGenCertCommand     =>
        "openssl req -newkey ec:$SYSTEMCONFIGDIR/openssl-ecparams.pem -x509 -days 2190 -nodes",
## Values declared as user values in /etc/tigervnc/vncserver-config-*, i.e.,
## values that are intended to be overwritten by ~/.vnc/tigervnc.conf.
      vncUserDir                =>
        File::Spec->catfile($ENV{HOME}, ".vnc"),
      vncPasswdFile             =>
        undef, # later derived from vncUserDir
      vncStartup                =>
        "/etc/X11/Xtigervnc-session",
      xauthorityFile            =>
        $ENV{XAUTHORITY} ||
        File::Spec->catfile($ENV{HOME}, ".Xauthority"),
      desktopName               => undef,
      wmDecoration              =>
        "8x64", # a guess at the typical size for a window manager decoration
      geometry                  => "1920x1200",
      depth                     => 24,
      pixelformat               => undef,
      getDefaultFrom            => undef,
      rfbwait                   => 30000,
      rfbport                   => undef,
      localhost                 => undef,
      SecurityTypes             =>
        undef, # later derived depening on localhost setting
      PlainUsers                =>
        undef, # later derived from /usr/bin/id -u -n
      X509Cert                  =>
        undef, # auto generated if absent and stored in
               # ~/.vnc/${HOSTFQDN}-SrvCert.pem
      X509Key                   =>
        undef, # auto generated if absent and stored in
               # ~/.vnc/${HOSTFQDN}-SrvKey.pem
      session                   => undef,
# Undocumented values
      vncServerExtraArgs        => [],
      cleanstale                => 0,
      clean                     => 0,
      displayNumber             => undef,
      displayHost               => undef,
      src                       => {},
    );

  foreach my $key (keys %options) {
    $opts->{$key} = $options{$key} unless defined $opts->{$key};
  }

  #
  # Then source in configuration files, first the site wide one and then the
  # user specific one.
  #
  &readConfigFile($opts, "defaults");

  if (!(-d $opts->{'vncUserDir'})) {
    # Create the user's vnc directory if necessary.
    if (-e $opts->{'vncUserDir'}) {
      print STDERR "$PROG: Could not create $opts->{'vncUserDir'}, file exists but is not a directory.\n";
      exit 1;
    }
    if (!mkpath ($opts->{'vncUserDir'}, 0, 0755)) {
      print STDERR "$PROG: Could not create $opts->{'vncUserDir'}.\n";
      exit 1;
    }
  }
  my $vncStartup = $opts->{'vncStartup'};
  $opts->{'vncStartup'} = '__AUTO__' if defined $vncStartup;

  &readConfigFile($opts, "user");

  $opts->{'usageError'} = !&parseCmdLine($opts);

  &handleVNCStartupAuto($vncStartup, $opts);

  if (defined $opts->{'displayHost'}) {
    if (!$opts->{'kill'} && !$opts->{'list'} && !$opts->{'version'}) {
      $opts->{'usageError'} = 1 if ($opts->{'displayNumber'}||"") eq '*';
    }
  }

  return $opts;
}

1;
__END__

# -- documentation -----------------------------------------------------------

=pod

=back

=head1 AUTHOR

Joachim Falk E<lt>joachim.falk@gmx.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 by Joachim Falk

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut
