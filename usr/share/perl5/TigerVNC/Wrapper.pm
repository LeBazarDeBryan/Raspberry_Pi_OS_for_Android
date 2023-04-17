package TigerVNC::Wrapper;

# Below is documentation for your module. You'd better edit it!
=pod

=head1 NAME

TigerVNC::Wrapper - TigerVNC server management

=head1 SYNOPSIS

  use TigerVNC::Config;
  use TigerVNC::Wrapper;

  my $options = { wrapperMode => 'tigervncserver' };

  # First, we ensure that we're operating in a sane environment.
  exit 1 unless &sanityCheck($options);

  # Next, parses the system /etc/tigervnc/vncserver-config-defaults and the user
  # ~/.vnc/tigervnc.conf configuration file as well as processes the command line.
  &getConfig($options);

  if ($options->{'kill'}) {
    my $err = &killVncServers($options);
    exit($err ? 1 : 0);
  } elsif ($options->{'list'}) {
    &listVncServers(\*STDOUT, $options);
    exit 0;
  } else {
    exit &startVncServer($options);
  }

=head1 DESCRIPTION

This module starts either a B<Xtigervnc> or B<X0tigervnc> server.

=cut

use strict;
use warnings;

use File::Spec;
use File::ReadBackwards;
use DirHandle;
use File::stat;
use IO::File;
use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END);
use Socket;
use Time::HiRes qw(usleep);
use Errno qw(:POSIX);
use POSIX qw(:sys_wait_h :fcntl_h setsid);

use TigerVNC::Common;
use TigerVNC::Config;

=pod

=head1 EXPORTS

=over 4

=item listVncServers

=item killVncServers

=item startVncServer

=back

=cut

use Exporter qw(import);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
our @EXPORT = qw(
  listVncServers
  killVncServers
  startVncServer
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

#=pod
#
#=head1 GLOBALS
#
#=over 4
#
#=item $MAGIC
#
#Magic prefix inside the logfile to identify currently running server information.
#
#=back
#
#=cut

our $MAGIC = '3NI3X0 ';

=pod

=head1 FUNCTIONS

=cut

#
# Check if tcp port is available
#
sub checkTCPPortUsed {
  my ($port) = @_;
  my $proto  = 6; # TCP protocol, i.e., getprotobyname('tcp');

  socket(S, PF_INET, SOCK_STREAM, $proto) || die "$PROG: socket failed: $!";
  setsockopt(S, SOL_SOCKET, SO_REUSEADDR, pack("l", 1)) || die "$PROG: setsockopt failed: $!";
  if (!bind(S, sockaddr_in($port, INADDR_ANY))) {
    # print "$PROG: bind ($port) failed: $!\n";
    close(S);
    return 1;
  }
  close(S);
  return 0;
}

#
# checkRFBPortUsed checks if the given RFB port is used by vnc.
# A RFB port n is used if something is listening on the VNC server port
# (5900+n).
#

sub checkRFBPortUsed{
  my ($n) = @_;
  return &checkTCPPortUsed(5900 + $n);
}

#
# checkDisplayNumberAvailable checks if the given display number is available.
# A display number n is taken if something is listening on the X server port
# (6000+n) or at least one of the X11 lock files /tmp/.X$n-lock or
# /tmp/.X11-unix/X$n is present.
#

sub checkDisplayNumberAvailable {
  my ($n) = @_;

  return 0 if &checkTCPPortUsed(6000 + $n);

  my $displayLock = 0;
  my $unixDisplaySocketPath = "/tmp/.X11-unix/X$n";

  socket(S, PF_UNIX, SOCK_STREAM, 0) || die "$PROG: socket failed: $!";
  if (connect(S, pack_sockaddr_un $unixDisplaySocketPath)) {
    close(S);
    return 0;
  } elsif (-e $unixDisplaySocketPath) {
    print "\nWarning: $HOSTFQDN:$n is taken because of /tmp/.X11-unix/X$n\n";
    print "Remove this file if there is no X server $HOSTFQDN:$n\n";
    $displayLock = 1;
  }
  close(S);

  if (-e "/tmp/.X$n-lock") {
    print "\nWarning: $HOSTFQDN:$n is taken because of /tmp/.X$n-lock\n";
    print "Remove this file if there is no X server $HOSTFQDN:$n\n";
    $displayLock = 1;
  }

  return $displayLock ? 0 : 1;
}

#
# getDisplayNumber gets the lowest available display number. A display number
# n is taken if something is listening on the VNC server port (5900+n) or the
# X server port (6000+n).
#

sub getDisplayNumber($) {
  my ($rfbport) = @_;

  if (defined($rfbport) && $rfbport >= 5900 && $rfbport <= 5999) {
    my $n = $rfbport - 5900;
    return $n if &checkDisplayNumberAvailable($n);
  }
  foreach my $n (1..99) {
    if (&checkDisplayNumberAvailable($n)) {
      return $n if defined $rfbport;
      return $n if !&checkTCPPortUsed(5900 + $n);
    }
  }

  print STDERR "$PROG: no free display number on $HOSTFQDN.\n";
  exit -1;
}

sub pidFile {
  my ($options, $rfbport) = @_;
  $rfbport = $options->{'rfbport'} unless defined $rfbport;
  return File::Spec->catfile($options->{'vncUserDir'},
    "${HOSTFQDN}:${rfbport}.pid");
}

sub x509CertFiles {
  my ($options) = @_;
  return (
    "$options->{'vncUserDir'}/${HOSTFQDN}-SrvCert.pem",
    "$options->{'vncUserDir'}/${HOSTFQDN}-SrvKey.pem");
}

sub desktopLog {
  my ($options, $rfbport) = @_;
  $rfbport = $options->{'rfbport'} unless defined $rfbport;
  return File::Spec->catfile($options->{'vncUserDir'},
    "${HOSTFQDN}:${rfbport}.log");
}

sub cleanStale($$$) {
  my ($options, $runningVncServers, $nr) = @_;
  my $usedDisplay = $runningVncServers->{$nr}->{'usedDisplay'};
  my $stale       = $runningVncServers->{$nr}->{'stale'};
  my $server      = $runningVncServers->{$nr}->{'server'};
  my $pidFile     = &pidFile($options,$nr);

  # vnc pidfile stale
  my $msg = "";
  if (-e $pidFile) {
    unless ($options->{'dry-run'} || unlink($pidFile) || $! == &ENOENT) {
      print STDERR "$PROG: Warning: Can't clean stale pidfile '$pidFile': $!\n";
    } elsif ($stale) {
      print "Cleaning stale pidfile '$pidFile'!\n";
    }
  }
  if ($server eq 'Xtigervnc') {
    if (!$stale || !&checkTCPPortUsed(6000 + $usedDisplay)) {
      my @X11Locks = ("/tmp/.X$usedDisplay-lock", "/tmp/.X11-unix/X$usedDisplay");
      foreach my $entry (grep { -e $_ } @X11Locks) {
        unless ($options->{'dry-run'} || unlink($entry) || $! == &ENOENT) {
          print STDERR "$PROG: Warning: Can't clean stale X11 lock '$entry': $!\n";
        } else {
          print "Cleaning stale X11 lock '$entry'!\n";
        }
      }
    }
  }
}

sub runningVncServers {
  my ($options) = @_;
  my %runningVncServers = ();

  my $d = DirHandle->new($options->{'vncUserDir'});
  if (defined $d) {
    while (defined(my $entry = $d->read)) {
      next unless $entry =~ m/^\Q$HOSTFQDN\E:(\d+)\.pid$/;
      my $nr = $1;
      my ($pid, $stale);
      {
        my $pidFile     = File::Spec->catfile($options->{'vncUserDir'}, $entry);
        my $pidFileFh   = IO::File->new($pidFile, "r");
        unless (defined $pidFileFh) {
          print STDERR "$PROG: Warning: Can't open pid file '$pidFile': $!\n";
          next;
        }
        unless (($pidFileFh->getline()//"") =~ m/^([0-9]+)$/) {
          print STDERR "$PROG: Warning: Can't parse pid file '$pidFile'!\n";
          next;
        }
        $pid   = int($1);
        $stale = !kill(0, $pid);
      }

      my ($usedDisplay, $rfbport) = (undef, undef);
      if ($nr <= 99) {
        $usedDisplay = $nr;
        $rfbport     = $nr + 5900;
      } else {
        $rfbport     = $nr;
        $usedDisplay = $nr - 5900 if $nr >= 5900 && $nr <= 5999;
      }
      my $name    = "$HOSTFQDN:$usedDisplay";
      my $client  = undef;
      my $server  = "Xtigervnc";
      my $DISPLAY = -e "/tmp/.X11-unix/X${usedDisplay}"
        ? ":${usedDisplay}"
        : "$HOSTFQDN:${usedDisplay}";
      {
        my $logFile     = desktopLog($options, $nr);
        my $logFileFh   = File::ReadBackwards->new($logFile);
        if (defined $logFileFh) {
          my $line;
          while (defined ($line = $logFileFh->readline)) {
            chomp $line;
            if ($line =~ m/Listening for VNC connections.* port\s+(\d+)/) {
              $rfbport = $1; last;
            } elsif ($line =~ m/^\Q$MAGIC\ENew (\w+) server '([^']*)' on port (\d+) for display (.*)\.$/) {
             # 3NI3X0 New X0tigervnc server 'xerstin.jfalk.de:21 (joachim)' on port 5921 for display :20.
             $server = $1; $name = $2; $rfbport = $3; $DISPLAY = $4;
             $usedDisplay = $1 if $DISPLAY =~ m/:(\d+)(?:\.\d+)?$/;
             last;
            } elsif ($line =~ m/^\Q$MAGIC\EUse (.*) to connect to the VNC server\.$/) {
              # 3NI3X0 Use xtigervncviewer -SecurityTypes X509Plain -X509CA /home/joachim/.vnc/xerstin.jfalk.de-SrvCert.pem xerstin.jfalk.de:21 to connect to the VNC server.
              $client = $1;
            }
          }
        }
      }
      unless (defined $client) {
        # Example client connection
        $client = "xtigervncviewer $HOSTFQDN:$rfbport";
      }
      $stale = 1 if $stale || !&checkTCPPortUsed($rfbport);
      my $vncServerEntry = {
          'name'        => $name,
          'server'      => $server,
          'client'      => $client,
          'pid'         => $pid,
          'DISPLAY'     => $DISPLAY,
          'usedDisplay' => $usedDisplay,
          'rfbport'     => $rfbport,
          'stale'       => $stale,
        };

      if ($options->{'cleanstale'} && $stale) {
        &cleanStale($options, { $nr => $vncServerEntry }, $nr);
        next;
      }
      # running VNC server if $options->{'cleanstale'}
      $runningVncServers{$nr} = $vncServerEntry;
    }
    undef $d;
  }
  return \%runningVncServers;
}

sub matchVncServers($$$) {
  my ($options, $runningVncServers, $includeStale) = @_;

  my $dn      = $options->{'displayNumber'};
  my $rfbport = $options->{'rfbport'};

  my @allVNCs = keys %{$runningVncServers};
  unless ($includeStale) {
    @allVNCs = grep { !$runningVncServers->{$_}->{'stale'} } @allVNCs;
  }
  my @vncs = @allVNCs;
  if (defined($dn) && $dn ne '*') {
    @vncs = grep {
      $runningVncServers->{$_}->{'usedDisplay'} eq $dn } @vncs;
  }
  if (defined $rfbport) {
    @vncs = grep {
      $runningVncServers->{$_}->{'rfbport'} eq $rfbport } @vncs;
  } elsif (@vncs == 0 && defined($dn) && $dn ne '*') {
    $rfbport = $dn <= 99 ? 5900 + $dn : $dn;
    @vncs = grep {
      $runningVncServers->{$_}->{'rfbport'} eq $rfbport } @allVNCs;
  }
  return @vncs;
}

sub statusReport($) {
  my ($status) = @_;

  if (WIFEXITED($status)) {
    my $exitval = WEXITSTATUS($status);
    return $exitval == 0
      ? "cleanly exited"
      : "exited with status $exitval";
  } elsif (WIFSIGNALED($status)) {
    my $termsig = WTERMSIG($status);
    return "died with signal $termsig";
  } else {
    return "died ($status)";
  }
}

=pod

=over 4

=item listVncServers

List the specified VNC server.

=cut

sub listVncServers {
  my ($fh, $options, $vncs, $runningVncServers) = @_;

  unless (defined $runningVncServers) {
    $runningVncServers = &runningVncServers($options);
  }
  unless (defined $vncs) {
    $vncs = [&matchVncServers($options, $runningVncServers, 1)];
  }
  # Sort running VNC server list
  $vncs = [sort {
      my $av = $runningVncServers->{$a}->{'usedDisplay'};
      my $bv = $runningVncServers->{$b}->{'usedDisplay'};
      return -1 if $av < $bv;
      return  1 if $av > $bv;
      $av = $runningVncServers->{$a}->{'rfbport'};
      $bv = $runningVncServers->{$b}->{'rfbport'};
      return -1 if $av < $bv;
      return  1 if $av > $bv;
      return  0;
    } @{$vncs}];

  print $fh
    "\n".
    "TigerVNC server sessions:\n".
    "\n".
    "X DISPLAY #\tRFB PORT #\tPROCESS ID\tSERVER\n";
  foreach my $vnc (@{$vncs}) {
    next unless defined $runningVncServers->{$vnc};
    my $stale   = $runningVncServers->{$vnc}->{'stale'}
      ? " (stale)" : "";
    my $rfbport = $runningVncServers->{$vnc}->{'rfbport'};
    my $dn      = $runningVncServers->{$vnc}->{'usedDisplay'};
    my $pid     = $runningVncServers->{$vnc}->{'pid'};
    my $server  = $runningVncServers->{$vnc}->{'server'};
    printf $fh ":%-10d\t%-10d\t%-10s\t%s\n", $dn, $rfbport, $pid.$stale, $server;
  }
}

=pod

=item killVncServers

Kill the specified VNC server.

=cut

#
# killVncServers
#

sub killVncServers {
  my ($options, $vncs, $runningVncServers) = @_;
  my $retval = 0;

  unless (defined $runningVncServers) {
    $runningVncServers = &runningVncServers($options);
  }
  unless (defined $vncs) {
    $vncs = [&matchVncServers($options, $runningVncServers)];
    if (@{$vncs} == 0) {
      if (!defined $options->{'rfbport'} &&
          (!defined $options->{'displayNumber'} || $options->{'displayNumber'} eq '*')) {
        print STDERR "$PROG: No VNC server running for this user!\n";
      } else {
        print STDERR "$PROG: No matching VNC server running for this user!\n";
      }
      $retval = 1;
    } elsif (@{$vncs} > 1 && ($options->{'displayNumber'}//'undef') ne '*') {
      print STDERR "$PROG: This is ambiguous. Multiple VNC servers are running for this user!\n";
      &listVncServers(\*STDERR, $options, $vncs, $runningVncServers);
      $retval = 1;
      $vncs = [];
    }
  }

  $SIG{'CHLD'} = 'IGNORE';
  foreach my $vnc (@{$vncs}) {
    my $stale       = \$runningVncServers->{$vnc}->{'stale'};
    my $pid         = $runningVncServers->{$vnc}->{'pid'};
    my $server      = $runningVncServers->{$vnc}->{'server'};
    my $usedDisplay = $runningVncServers->{$vnc}->{'usedDisplay'};

    next unless defined $pid;
    print "Killing $server process ID $pid...";
    unless ($options->{'dry-run'}) {
      if (kill('TERM', $pid)) {
        my $i = 10;
        for (; $i >= 0; $i = $i-1) {
          last unless kill(0, $pid);
          usleep 100000;
        }
        if ($i >= 0) {
          print " success!\n";
        } else {
          $retval = 1;
          print " which seems to be deadlocked. Using SIGKILL!\n";
          unless (kill('KILL', $pid) || $! == &ESRCH) {
            print STDERR "Can't kill '$pid': $!\n";
            next;
          }
        }
      } elsif ($! == &ESRCH) {
        print " which was already dead\n";
        $$stale = 1;
      } else {
        $retval = 1;
        print STDERR "\nCan't kill '$pid': $!\n";
        next;
      }
    }
    &cleanStale($options, $runningVncServers, $vnc);

    # If option -clean is given, also remove the logfile
    if (!$options->{'dry-run'} && $options->{'clean'}) {
      my $desktopLog = &desktopLog($options, $vnc);
      unless (unlink($desktopLog) || $! == &ENOENT) {
        $retval = 1;
        print STDERR "Can't remove '$desktopLog': $!\n";
      }
    }
  }
  $SIG{'CHLD'} = 'DEFAULT';
  return $retval;
}

# Make an X server cookie
sub CreateMITCookie {
  my ( $options ) = @_;
  my $displayNumber  = $options->{'displayNumber'};
  my $xauthorityFile = $options->{'xauthorityFile'};
  my $cookie = `mcookie`; # try mcookie

  unless (defined $cookie) {
    # mcookie failed => make an X server cookie the old fashioned way
    srand(time+$$+unpack("L",`cat $options->{'vncPasswdFile'}`));
    $cookie = "";
    for (1..16) {
      $cookie .= sprintf("%02x", int(rand(256)));
    }
  } else {
    chomp $cookie;
  }
  system(getCommand("xauth"), "-f", "$xauthorityFile", "add", "$HOSTFQDN:$displayNumber", ".", "$cookie");
  system(getCommand("xauth"), "-f", "$xauthorityFile", "add", "$HOST/unix:$displayNumber", ".", "$cookie");
}

# Make sure the user has a password.
sub CreateVNCPasswd {
  my ( $options ) = @_;

  my $passwordArgSpecified =
    ($options->{'src'}{'vncPasswdFile'}//"undef") eq "cmdline";

  # Check whether VNC authentication is enabled, and if so, prompt the user to
  # create a VNC password if they don't already have one.
  return if !$options->{'vncAuthEnabled'} || $passwordArgSpecified;
  my $vncPasswdFile = $options->{'vncPasswdFile'};
  my $st = stat($vncPasswdFile);

  if (!defined($st) || ($st->mode & 077)) {
    print "\nYou will require a password to access your desktops.\n\n";
    unless (unlink($vncPasswdFile) || $! == &ENOENT) {
      print STDERR "Can't remove old vnc passwd file '$vncPasswdFile': $!!\n";
      exit 1;
    }
    system(getCommand("tigervncpasswd"), $vncPasswdFile);
    exit 1 if (($? >> 8) != 0);
  }
}

# Make sure the user has a x509 certificate.
sub CreateX509Cert {
  my ( $options ) = @_;

  # Check whether X509 encryption is enabled, and if so, create
  # a self signed certificate if not already present or specified
  # on the command line.
  return if !$options->{'x509CertRequired'} ||
            defined $options->{'X509Cert'} ||
            defined $options->{'X509Key'};
  ($options->{'X509Cert'}, $options->{'X509Key'}) =
    &x509CertFiles($options);

  my $st = stat($options->{'X509Key'});
  if (!defined($st) || ($st->mode & 077) || !-f $options->{'X509Cert'}) {
    print "\nYou will require a certificate to use X509None, X509Vnc, or X509Plain.\n";
    print "I will generate a self signed certificate for you in $options->{'X509Cert'}.\n\n";
    unless (unlink($options->{'X509Cert'}) || $! == &ENOENT) {
      print STDERR "Can't remove old X509Cert file '$options->{'X509Cert'}': $!!\n";
      exit 1;
    }
    unless (unlink($options->{'X509Key'}) || $! == &ENOENT) {
      print STDERR "Can't remove old X509Key file '$options->{'X509Key'}': $!!\n";
      exit 1;
    }
    my $toSSLFh;
    my @CMD = split(/\s+/, $options->{'sslAutoGenCertCommand'});
    $CMD[0] = &getCommand($CMD[0]);
    push @CMD, "-config", "-" unless grep { $_ eq "-config" } @CMD;
    push @CMD, "-out", $options->{'X509Cert'} unless grep { $_ eq "-out" } @CMD;
    push @CMD, "-keyout", $options->{'X509Key'} unless grep { $_ eq "-keyout" } @CMD;
    unless (defined open($toSSLFh, "|-", @CMD)) {
      print STDERR "Can't start openssl pipe: $!!\n";
      exit 1;
    }
    my $configSSLFh;
    unless (defined open($configSSLFh, "<", "$SYSTEMCONFIGDIR/openssl.cnf")) {
      print STDERR "Can't open openssl configuration template $SYSTEMCONFIGDIR/openssl.cnf: $!\n";
      exit 1;
    }
    while (my $line = <$configSSLFh>) {
      $line =~ s/\@HostName\@/$HOSTFQDN/;
      print $toSSLFh $line;
    }
    close $configSSLFh;
    close $toSSLFh;
    if ($? != 0) {
      unlink $options->{'X509Cert'};
      unlink $options->{'X509Key'};
      print STDERR "The openssl command ", join(' ', @CMD), " failed: $?\n";
      exit 1;
    }
  }
}

=pod

=item startVncServer

Start an I<Xtigervnc> or I<X0tigervnc> server.

  &startVncServer($options);

=cut

# Now start the X VNC Server
sub startVncServer {
  my ($options) = @_;

  # Read in mandatory configuration information
  &readConfigFile($options, "mandatory");

  unless (defined $options->{'PlainUsers'}) {
    $options->{'PlainUsers'} = $USER;
  }
  unless (defined $options->{'PAMService'}) {
    if (-f '/etc/pam.d/vnc') {
      $options->{'PAMService'} = 'vnc';
    } else {
      # Default vnc service not present. Hence, we fall back to our own tigervnc service.
      $options->{'PAMService'} = 'tigervnc';
    }
  }

  unless (defined $options->{'vncPasswdFile'}) {
    $options->{'vncPasswdFile'} =
      File::Spec->catfile($options->{'vncUserDir'}, "passwd");
  }
  if (defined $options->{'session'} &&
      ref($options->{'session'}) eq '') {
    $options->{'session'} = [split(qr{\s+}, $options->{'session'})];
  } elsif (!defined $options->{'session'} ||
           ref($options->{'session'}) ne 'ARRAY') {
    $options->{'session'} = [];
  }
  unless (defined $options->{'SecurityTypes'}) {
    if (!defined($options->{'localhost'}) || $options->{'localhost'}) {
      $options->{'SecurityTypes'} = 'VncAuth';
      $options->{'localhost'}     = 1;
    } else {
      $options->{'SecurityTypes'} = 'VncAuth,TLSVnc';
      $options->{'localhost'}     = 0;
    }
  }
  $options->{'vncAuthEnabled'} = 0;
  $options->{'noneAuthEnabled'} = 0;
  $options->{'plainAuthEnabled'} = 0;
  $options->{'x509CertRequired'} = 0;
  $options->{'haveSSLEncryption'} = 0;
  foreach my $securityType (split(',', $options->{'SecurityTypes'})) {
    $options->{'vncAuthEnabled'} = 1    if $securityType =~ m/^(?:.*vnc|vncauth)$/i;
    $options->{'noneAuthEnabled'} = 1   if $securityType =~ m/none$/i;
    $options->{'plainAuthEnabled'} = 1  if $securityType =~ m/plain$/i;
    $options->{'x509CertRequired'} = 1  if $securityType =~ m/^x509/i;
    $options->{'haveSSLEncryption'} = 1 if $securityType =~ m/^(?:x509|tls)/i;
  }

  if ($options->{'plainAuthEnabled'} &&
      $options->{'PAMService'} eq 'tigervnc' &&
      ! -f '/etc/pam.d/tigervnc') {
    print STDERR "$PROG: The tigervnc PAM servcice required for the security types\n";
    print STDERR "\tPlain, TLSPlain, or X509Plain is not installed.\n";
    &installPackageError("tigervnc-common");
  }

  unless (defined $options->{'localhost'}) {
    # If we have no encrypted VNC connection security types or
    # we have at least one *None security type in there, then
    # we better only server VNC on localhost to be tunneled via
    # ssh.
    $options->{'localhost'} =
        (!$options->{'haveSSLEncryption'} || $options->{'noneAuthEnabled'}) ? 1 : 0;
  }
  # PREVENT THE USER FROM EXPOSING A VNC SESSION WITHOUT AUTHENTICATION
  # TO THE WHOLE INTERNET!!!
  if (!$options->{'localhost'} && $options->{'noneAuthEnabled'} &&
      !$options->{'I-KNOW-THIS-IS-INSECURE'}) {
    print STDERR "$PROG: YOU ARE TRYING TO EXPOSE A VNC SERVER WITHOUT ANY\n";
    print STDERR "AUTHENTICATION TO THE WHOLE INTERNET! I AM REFUSING TO COOPERATE!\n\n";
    print STDERR "If you really want to do that, add the --I-KNOW-THIS-IS-INSECURE option!\n";
    return -1;
  }
  if ($options->{'noneAuthEnabled'} &&
      !$options->{'I-KNOW-THIS-IS-INSECURE'}) {
    print STDERR "Please be aware that you are exposing your VNC server to all users on the\n";
    print STDERR "local machine. These users can access your server without authentication!\n";
  }

  unless ($options->{'vncAuthEnabled'}) {
    delete $options->{'vncPasswdFile'};
  }
  unless ($options->{'plainAuthEnabled'}) {
    delete $options->{'PAMService'};
    delete $options->{'PlainUsers'};
  }
  unless ($options->{'x509CertRequired'}) {
    delete $options->{'X509Cert'};
    delete $options->{'X509Key'};
  }

  my $runningVncServers = &runningVncServers($options);
  my $haveOld = undef;
  if ($options->{'useold'}) {
    my @vncs = &matchVncServers($options, $runningVncServers);
    if (@vncs == 1) {
      $haveOld = $runningVncServers->{$vncs[0]};
      $options->{'displayNumber'} = $haveOld->{'usedDisplay'};
      $options->{'rfbport'}       = $haveOld->{'rfbport'};
    } elsif (@vncs > 1) {
      print STDERR "$PROG: This is ambiguous. Multiple vncservers are running for this user!\n";
      &listVncServers(\*STDERR, $options, \@vncs, $runningVncServers);
      return 1;
    }
  }
  unless (defined $options->{'displayNumber'}) {
    # Find display number.
    $options->{'displayNumber'} = &getDisplayNumber($options->{'rfbport'});
  }
  unless (defined $options->{'rfbport'}) {
    $options->{'rfbport'} = 5900 + $options->{'displayNumber'};
  }
  unless (defined $options->{'desktopName'}) {
    my $rfbport = $options->{'rfbport'};
    $rfbport -= 5900 if $rfbport >= 5900 && $rfbport <= 5999;
    $options->{'desktopName'} = "${HOSTFQDN}:$rfbport ($USER)";
  }
  if (defined $haveOld) {
    my $DISPLAY = $haveOld->{'DISPLAY'};
    print "\nReusing old VNC server '$options->{desktopName}' for display $DISPLAY.\n";
    print "Use $haveOld->{'client'} to connect to the VNC server.\n";
    return 0;
  }
  if ($options->{'wrapperMode'} eq 'tigervncserver') {
    my $dn = $options->{'displayNumber'};
    my @vncs = ();
    foreach my $vnc (keys %{$runningVncServers}) {
      next unless $runningVncServers->{$vnc}->{'usedDisplay'} eq $dn;
      next unless $runningVncServers->{$vnc}->{'server'} eq 'Xtigervnc';
      if ($runningVncServers->{$vnc}->{'stale'}) {
        &cleanStale($options, $runningVncServers, $vnc);
      } else {
        push @vncs, $vnc;
      }
    }
    if (@vncs > 0) {
      print STDERR "A Xtigervnc server is already running for display :$dn on machine $HOSTFQDN.\n";
      return 1;
    } elsif (!&checkDisplayNumberAvailable($dn)) {
      print STDERR "A X11 server is already running for display :$dn on machine $HOSTFQDN.\n";
      return 1;
    }
  }
  if (&checkTCPPortUsed($options->{'rfbport'})) {
    my $rfbport = $options->{'rfbport'};
    my @vncs = grep {
        !$runningVncServers->{$_}->{'stale'} &&
        ($runningVncServers->{$_}->{'rfbport'} eq $rfbport)
      } keys %{$runningVncServers};
    if ($rfbport >= 5900 && $rfbport <= 5999) {
      $rfbport -= 5900;
      print STDERR "A VNC server is already running as :$rfbport on machine $HOSTFQDN.\n";
    } elsif (@vncs > 0) {
      print STDERR "A VNC server is already listening at port $rfbport on machine $HOSTFQDN.\n";
    } else {
      print STDERR "Something else is already listening at port $rfbport on machine $HOSTFQDN.\n";
    }
    return 1;
  }

  my $vncStartup = $options->{'vncStartup'};
  my $desktopLog = &desktopLog($options);
  my $pidFile    = &pidFile($options);

  # Make sure the user has a password if required.
  &CreateVNCPasswd($options);
  # Make sure the user has a x509 certificate if required.
  &CreateX509Cert($options);
  &CreateMITCookie($options) if $options->{'wrapperMode'} eq 'tigervncserver';

  my $pidFileFh  = IO::File->new($pidFile, "w", 0644);
  unless (defined $pidFileFh) {
    print STDERR "$PROG: Can't create pid file '$pidFile': $!\n";
    unlink($pidFile);
    return 1;
  }
  unlink($pidFile) if $options->{'dry-run'};

  my $desktopLogFh = IO::File->new($desktopLog, "a+");
  unless (defined $desktopLogFh && seek($desktopLogFh, 0, SEEK_END)) {
    print STDERR "$PROG: Can't open log file '$desktopLog' for append: $!\n";
    unlink($pidFile);
    return 1;
  }

  my $terminate = 0;
  $SIG{TERM} = sub { $terminate = 1; };
  $SIG{INT}  = sub { $terminate = 1; };
  $SIG{HUP}  = sub { $terminate = 1; };

  pipe STATUS_RH, STATUS_WH or die "Can't open pipe: $!";
  fcntl(STATUS_RH, F_SETFD, FD_CLOEXEC) or
    print STDERR "$PROG: Oops, setting close on exec failed: $!\n";
  fcntl(STATUS_WH, F_SETFD, FD_CLOEXEC) or
    print STDERR "$PROG: Oops, setting close on exec failed: $!\n";

  my $childPid = $options->{'fg'} ? 0 : fork();

  if ($childPid == 0) {
    # I am the child
    close STATUS_RH unless $options->{'fg'};

    my %childStatus;
    $SIG{CHLD} = sub {
        while ((my $child = waitpid(-1, WNOHANG)) > 0) {
          $childStatus{$child} = $?;
        }
      };

    # PID of the Xtigervnc or X0tigervnc server.
    my $xvncServerPid;
    # PID of the script starting the applications running in the VNC session.
    my $vncSessionPid;
    # X DISPLAY shared by the VNC server.
    my $DISPLAY;
    # Error flag for reporting to parent.
    my $error = 0;

    # Starting up the Xtigervnc or X0tigervnc server.
    {
      my @cmd;
      if ($options->{'wrapperMode'} eq 'tigervncserver') {
        push @cmd, getCommand("Xtigervnc");
        push @cmd, ":".$options->{'displayNumber'};
      } else {
        push @cmd, getCommand("X0tigervnc");
      }
      foreach my $optionParseEntry (@{&getOptionParseTable($options)}) {
        my ($flags, $optname, $store) = @{$optionParseEntry};
        if ($options->{'wrapperMode'} eq 'x0tigervncserver') {
          next unless $flags & &OPT_X0TIGERVNC;
        } else {
          next unless $flags & &OPT_XTIGERVNC;
        }
        $optname =~ m/^([^:=|]*)/;
        my $name = $1;
        my $value = &{$store}($name);
        if ($optname =~ m/:/) {
          push @cmd, "-$name=$value" if defined $value;
        } elsif ($optname =~ m/=/) {
          push @cmd, "-$name", $value if defined $value;
        } else {
          die "Oops, can't parse $optname format!";
        }
      }
  #   push @cmd, '-pn';
      push @cmd, map { @{$_->{'args'}} } @{$options->{'vncServerExtraArgs'}};

      if ($options->{'verbose'} || $options->{'dry-run'}) {
        print "Starting ",join(" ",@cmd), "\n";
      }
      $xvncServerPid = fork();
      die "Failed to fork: $!" if $xvncServerPid < 0;

      if ($xvncServerPid == 0) {
        # I am the child
        close STATUS_RH;
        close STATUS_WH;

        # Detach ourselves from the terminal
        setsid() or die "Cannot detach from controlling terminal: $!";
        # Prevent possibility of acquiring a controlling terminal
        $SIG{'HUP'} = 'IGNORE';

        $desktopLogFh->close();
        $desktopLogFh = undef;
        open(OLDERR, '>&', \*STDERR); # save old STDERR
        open(STDOUT, '>>', $desktopLog);
        open(STDERR, '>>', $desktopLog);
        OLDERR->autoflush(1);
        STDERR->autoflush(1);
        STDOUT->autoflush(1);
        fcntl(OLDERR, F_SETFD, FD_CLOEXEC) or
          print STDERR "$PROG: Oops, setting close on exec failed: $!\n";

        exit 0 if $options->{'dry-run'};
        exec {$cmd[0]} (@cmd) or
          print OLDERR "$PROG: Can't exec '".$cmd[0]."': $!\n";
        exit 1;
      }
      $pidFileFh->print($xvncServerPid."\n");
      $pidFileFh->close();

      $runningVncServers = {
          $options->{'rfbport'} => {
              'name'        => "$HOSTFQDN:".$options->{'displayNumber'},
              'server'      => $options->{'wrapperMode'} eq 'tigervncserver'
                                 ? "Xtigervnc" : "X0tigervnc",
              'stale'       => 0,
              'pid'         => $xvncServerPid,
              'rfbport'     => $options->{'rfbport'},
              'usedDisplay' => $options->{'displayNumber'},
            }
        };
      # Wait for Xtigervnc/X0tigervnc to start up
      unless ($options->{'dry-run'}) {
        my $i = 300;
        for (; $i >= 0; $i = $i-1) {
          if (&checkTCPPortUsed($options->{'rfbport'})) {
            last; # success
          }
          if (defined $childStatus{$xvncServerPid}) {
            $i = -2; last; # error
          }
          if ($terminate) {
            $i = -3; last; # error
          }
          usleep 100000;
        }
        if ($options->{'wrapperMode'} eq 'tigervncserver') {
          for (; $i >= 0; $i = $i-1) {
            if (-e "/tmp/.X11-unix/X$options->{'displayNumber'}" ||
                &checkTCPPortUsed(6000 + $options->{'displayNumber'})) {
              last; # success
            }
            if (defined $childStatus{$xvncServerPid}) {
              $i = -2; last; # error
            }
            if ($terminate) {
              $i = -3; last; # error
            }
            usleep 100000;
          }
        }
        if ($i < 0) {
          if (kill(0, $xvncServerPid)) {
            &killVncServers($options, [$options->{'rfbport'}], $runningVncServers);
          } else {
            &cleanStale($options, $runningVncServers, $options->{'rfbport'});
          }
          if ($i >= -2) {
            my $header = "=================== tail $desktopLog ===================";
            print STDERR "\n${header}\n";
            while (my $line = <$desktopLogFh>) {
              chomp $line;
              print STDERR $line, "\n";
            }
            print STDERR ("=" x length $header)."\n\n";
            $error = 1;
          }
          if ($i == -1) {
            print STDERR "$PROG: $cmd[0] did not start up, please look into '$desktopLog' to determine the reason! $i\n";
          } elsif ($i == -2) {
            my $status = &statusReport($childStatus{$xvncServerPid});
            print STDERR "$PROG: $cmd[0] $status, please look into '$desktopLog' to determine the reason! $i\n";
          }
          $xvncServerPid = undef;
          $runningVncServers = {};
        }
      }
      # Check if Xtigervnc/X0tigervnc has been started up successfully.
      if (defined $xvncServerPid) {
        # Xtigervnc/X0tigervnc is running. Thus, report some connection information.

        # If the unix domain socket exists then use that (DISPLAY=:n) otherwise use
        # TCP (DISPLAY=host:n)
        $DISPLAY = -e "/tmp/.X11-unix/X$options->{'displayNumber'}"
          ? ":$options->{'displayNumber'}"
          : "$HOSTFQDN:$options->{'displayNumber'}";
        my $rfbport = $options->{'rfbport'};
        my @status;
        {
          my $server = $options->{'wrapperMode'} eq 'tigervncserver'
            ? 'Xtigervnc' : 'X0tigervnc';
          push @status, "New $server server '$options->{desktopName}' on port $rfbport for display $DISPLAY.";
        }
        {
          $rfbport -= 5900 if $rfbport >= 5900 && $rfbport <= 5999;
          my @cmd = ("xtigervncviewer");
          push @cmd, "-SecurityTypes", $options->{'SecurityTypes'};
          push @cmd, "-X509CA", $options->{'X509Cert'} if $options->{'x509CertRequired'};
          push @cmd, "-passwd", $options->{'vncPasswdFile'} if $options->{'vncAuthEnabled'};
          push @cmd, $options->{'localhost'}
            ? ":$rfbport" : "$HOSTFQDN:$rfbport";
          push @status, "Use ".join(" ", @cmd)." to connect to the VNC server.";
        }
        print "\n";
        foreach my $status (@status) {
          $desktopLogFh->print($MAGIC.$status."\n");
          print $status."\n";
        }
        print "\n";
        $desktopLogFh->flush();
      }
    }
    if (defined($xvncServerPid) &&
        $options->{'wrapperMode'} eq 'tigervncserver') {
      if (defined $vncStartup) {
        # Run the X startup script.

        if ($options->{'verbose'}) {
          print "Starting session",
            (map { " ".&quotedString($_) } @{$options->{'session'}}),
            " via ", &quotedString($vncStartup), "\n";
          print "Log file is $desktopLog\n\n";
        }

        seek($desktopLogFh, 0, SEEK_END);

        my @cmd = ($vncStartup);
        push @cmd, @{$options->{'session'}};

        $vncSessionPid = fork();
        die "Failed to fork: $!" if $vncSessionPid < 0;

        if ($vncSessionPid == 0) {
          # I am the child
          close STATUS_RH;
          close STATUS_WH;

          # Detach ourselves from the terminal
          setsid() or die "Cannot detach from controlling terminal: $!";
          # Prevent possibility of acquiring a controlling terminal
          $SIG{'HUP'} = 'IGNORE';

          $desktopLogFh->close();
          $desktopLogFh = undef;
          open(OLDERR, '>&', \*STDERR); # save old STDERR
          open(STDOUT, '>>', $desktopLog);
          open(STDERR, '>>', $desktopLog);
          OLDERR->autoflush(1);
          STDERR->autoflush(1);
          STDOUT->autoflush(1);
          fcntl(OLDERR, F_SETFD, FD_CLOEXEC) or
            print STDERR "$PROG: Oops, setting close on exec failed: $!\n";

          $ENV{DISPLAY}    = $DISPLAY;
          $ENV{VNCDESKTOP} = $options->{'desktopName'};
          @cmd = qw(sleep 6) if $options->{'dry-run'};
          exec {$cmd[0]} (@cmd) or
            print OLDERR "$PROG: Can't exec '".$cmd[0]."': $!\n";
          exit 1;
        }
        # Wait for three seconds for erros to appear.
        {
          my $alarm = 0;
          $SIG{'ALRM'} = sub { $alarm = 1; };
          alarm 3;
          while (!$alarm && !$terminate &&
                 !defined $childStatus{$vncSessionPid}) {
            # Wait some more
            sleep 3600;
          }
          $SIG{'ALRM'} = 'DEFAULT';
        }
        if (!$terminate && defined $childStatus{$vncSessionPid}) {
          my $header = "=================== tail $desktopLog ===================";
          print STDERR "\n${header}\n";
          while (my $line = <$desktopLogFh>) {
            chomp $line;
            print STDERR $line, "\n";
          }
          print STDERR ("=" x length $header);
          print STDERR "\n\nSession startup via ",
            join(" ", map { &quotedString($_); } @cmd);
          my $status = &statusReport($childStatus{$vncSessionPid});
          if ($childStatus{$vncSessionPid} != 0) {
            print STDERR " $status!\n";
          } else {
            print STDERR " $status too early (< 3 seconds)!\n";
          }
          print STDERR "\nMaybe try something simple first, e.g.,\n";
          print STDERR "\ttigervncserver -xstartup /usr/bin/xterm\n";
          $error = 1;
        }
      } else { # !defined $vncStartup
        # Nothing to start. Check if autokill is enabled. Then, the Xtigervnc
        # server must be terminated.
        $terminate = 2 if $options->{'autokill'};
      }
    }
    if (defined $xvncServerPid) {
      unless ($terminate || $error || $options->{'fg'}) {
        # Detach ourselves from the terminal
        setsid() or die "Cannot detach from controlling terminal: $!";
        # Prevent possibility of acquiring a controlling terminal
        $SIG{'HUP'} = 'IGNORE';

        $desktopLogFh->close();
        undef $desktopLogFh;
        open(STDOUT, '>>', $desktopLog);
        open(STDERR, '>>', $desktopLog);
        STDERR->autoflush(1);
        STDOUT->autoflush(1);
        syswrite STATUS_WH, ($error ? "ERR" : "OK!");
      }
      while (
        # Check for terminate flag
        !$terminate &&
        # Check for error flag
        !$error &&
        # Check that the VNC server is still running.
        !defined($childStatus{$xvncServerPid}) &&
        # Check that the applications are still running if they were started.
        (!defined($vncSessionPid) || !defined($childStatus{$vncSessionPid})))
      {
        # Wait for SIGCHLD
        sleep 3600;
      }
      if (defined $childStatus{$xvncServerPid}) {
        $error = 1 if $childStatus{$xvncServerPid} != 0;
        my $server = $runningVncServers->{$options->{'rfbport'}}->{'server'};
        my $status = &statusReport($childStatus{$xvncServerPid});
        print "The $server server $status!\n";
      }
      if (defined($vncSessionPid) && defined($childStatus{$vncSessionPid})) {
        $error = 1 if $childStatus{$vncSessionPid} != 0;
        my $status = &statusReport($childStatus{$vncSessionPid});
        print "The X session $status!\n";
      }
      if ($terminate || $error || $options->{'autokill'}) {
        if (kill(0, $xvncServerPid)) {
          &killVncServers($options, [$options->{'rfbport'}], $runningVncServers);
        } else {
          &cleanStale($options, $runningVncServers, $options->{'rfbport'});
        }
      }
    }
    syswrite STATUS_WH, ($error ? "ERR" : "OK!");
    exit 0 unless $options->{'fg'};
  }
  # I am the parent
  close STATUS_WH;
  my $status = "";
  do {
    $! = 0;
    sysread STATUS_RH, $status, 3;
  } while ($! == EINTR);
  $status = 'ERR' if $status eq "";
  return ($status eq 'OK!') ? 0 : -1;
}

1;
__END__

# -- documentation -----------------------------------------------------------

=pod

=back

=head1 AUTHOR

Joachim Falk E<lt>joachim.falk@gmx.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004-2021 Joachim Falk <joachim.falk@gmx.de>

Copyright (C) 2017 Philipp Wolski <philipp.wolski@kisters.de>

Copyright (C) 2004 Ola Lundqvist <opal@debian.org>

Copyright (C) 2004 Marcus Brinkmann <Marcus.Brinkmann@ruhr-uni-bochum.de>

Copyright (C) 2004 Dirk Eddelbuettel <edd@debian.org>

Copyright (C) 2002-2003 RealVNC Ltd.

Copyright (C) 1999 AT&T Laboratories Cambridge.  All Rights Reserved.

Copyright (C) 1997, 1998 Olivetti & Oracle Research Laboratory

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut
