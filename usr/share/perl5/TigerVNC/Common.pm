package TigerVNC::Common;

# Below is documentation for your module. You'd better edit it!
=pod

=head1 NAME

TigerVNC::Common - Common infrastructure

=head1 SYNOPSIS

  use TigerVNC::Common;

  # Either that or wrapperMode => 'tigervncserver'
  my $options =  { wrapperMode => 'x0tigervncserver' }; 

  #
  # First, we ensure that we're operating in a sane environment.
  #
  exit 1 unless &sanityCheck($options);

  my $xdpyinfo = &getCommand("xdpyinfo");

=head1 DESCRIPTION

This module provides common infrastructure to both TigerVNC::Config and TigerVNC::Wrapper.

=cut

use strict;
use warnings;

use File::Spec;
use File::Basename qw(dirname basename);

=pod

=head1 EXPORTS

=over

=item $PROG

=item $HOST

=item $HOSTFQDN

=item $USER

=item $ROWS

=item $COLUMNS

=item $SYSTEMCONFIGDIR

=item &sanityCheck

=item &getCommand

=item &quotedString


=back

=cut

use Exporter qw(import);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
our @EXPORT = qw(
  $PROG
  $HOST $HOSTFQDN
  $USER
  $ROWS $COLUMNS
  $SYSTEMCONFIGDIR
  sanityCheck
  getCommand
  quotedString
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

=cut

our %CMDS;

# Populate %CMDS
{
  # Get install base bin dir
  my $binbase = dirname(File::Spec->rel2abs($0));

  foreach my $cmd (qw(
    hostname xauth Xtigervnc X0tigervnc tigervncpasswd openssl xdpyinfo))
  {
    foreach my $dir ($binbase, split(/:/,$ENV{PATH})) {
      my $fqcmd = File::Spec->catfile($dir, $cmd);
      if (-x $fqcmd) {
        $CMDS{$cmd} = $fqcmd;
        last;
      }
    }
  }
}

=pod

=over 4

=item $PROG

The program using this package.

=cut

# Get the program name
our $PROG = basename($0);

=pod

=item $HOST

The host name of this machine, i.e., the result of B<`hostname`>.

=item $HOSTFQDN

The fully qualified host name of this machine, i.e., the result of B<`hostname -f`>.

=cut

our ($HOST, $HOSTFQDN);

# Derive the host name
if (defined $CMDS{'hostname'}) {
  my $hostname = $CMDS{'hostname'};
  chomp($HOST     = `$hostname`);
  chomp($HOSTFQDN = `$hostname -f`);
  undef $HOST     if $HOST     eq "";
  undef $HOSTFQDN if $HOSTFQDN eq "";
}

=pod

=item $USER

The user name of the uid using this package, e.g., the result of B<`id -u -n`>.

=cut

our $USER;

# Derive the username
{
  $USER = getpwuid($<);
  undef $USER if $USER eq "";
}

=pod

=item $ROWS and $COLUMNS

The number of rows and columns of the terminal if a terminal is present.

=cut

our $ROWS = undef;
our $COLUMNS = 80;

eval {
  require 'sys/ioctl.ph';
  die "no TIOCGWINSZ" unless defined &TIOCGWINSZ;
  open(TTY, "+</dev/tty") or die "No tty: $!";
  my $winsize='';
  unless (ioctl(TTY, &TIOCGWINSZ, $winsize)) {
    die sprintf "$0: ioctl TIOCGWINSZ (%08x: $!)\n", &TIOCGWINSZ;
  }
  close TTY;
  ($ROWS, $COLUMNS) = unpack('S2', $winsize);
};

=pod

=item $SYSTEMCONFIGDIR

The system configuration directory for TigerVNC, i.e., I</etc/tigervnc>.

=cut

our $SYSTEMCONFIGDIR = "/etc/tigervnc";

=pod

=back

=head1 FUNCTIONS

=cut

sub installPackageError {
  my ($package) = @_;
  print STDERR "\tPlease install the $package package, i.e., sudo apt-get install $package.\n";
}

=pod

=over 4

=item sanityCheck

Routine to make sure we're operating in a sane environment.
Returns 1 if we run in a sane environment, 0 otherwise.


=cut 

sub sanityCheck {
  my ($options) = @_;
  #
  # Check we have all the commands we'll need on the path.
  #
  getCommand('hostname');
  if (($options->{'wrapperMode'}//"undef") eq 'tigervncserver') {
    getCommand('xauth');
    getCommand('Xtigervnc');
  } elsif (($options->{'wrapperMode'}//"undef") eq 'x0tigervncserver') {
    getCommand('X0tigervnc');
  }
  #
  # Check the HOME environment variable is set
  #
  unless (defined $ENV{HOME}) {
    print STDERR "$PROG: The HOME environment variable must be set.\n";
    return 0;
  }
  #
  # Check that we have a host name and also a fully qualified one.
  #
  unless (defined $HOST) {
    print STDERR "$PROG: Could not acquire host name of this machine.\n";
    return 0;
  }
  unless (defined $HOSTFQDN) {
    print STDERR "$PROG: Could not acquire fully qualified host name of this machine.\n";
    return 0;
  }
  #
  # Check that we have a user name.
  #
  unless (defined $USER) {
    print STDERR "$PROG: I do not know who you are.\n";
    return 0;
  }
  return 1;
}

=pod

=item getCommand

Function that derives the absolute path for one of the following programs:
B<hostname>, B<xauth>, B<xdpyinfo>, B<openssl>, B<tigervncpasswd>,
B<Xtigervnc>, B<X0tigervnc>.

=cut

sub getCommand {
  my ($cmd) = @_;

  return $CMDS{$cmd} if defined $CMDS{$cmd};
  print STDERR "$PROG: Couldn't find \"$cmd\" on your PATH.\n";
  &installPackageError("tigervnc-common") if $cmd eq 'tigervncpasswd';
  &installPackageError("openssl") if $cmd eq 'openssl';
  &installPackageError("x11-utils") if $cmd eq 'xdpyinfo';
  exit 1;
}

=pod

=item quotedString

Function that returns a string which yields the original string when parsed
by a shell.

=cut

sub quotedString {
  my ($in) = @_;
  $in =~ s/\'/\'\"\'\"\'/g;
  return "'$in'";
}

1;
__END__

# -- documentation -----------------------------------------------------------

=pod

=back

=head1 AUTHOR

Joachim Falk E<lt>joachim.falk@gmx.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 Joachim Falk <joachim.falk@gmx.de>

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut
