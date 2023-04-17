package TigerVNC::OptionTie;

# Below is documentation for your module. You'd better edit it!
=pod

=head1 NAME

TigerVNC::OptionTie - Helper package for TigerVNC::Config

=head1 SYNOPSIS

  use TigerVNC::OptionTie;

  tie ${"config::$name"}, 'TigerVNC::OptionTie', sub { &{$store}($name, @_) };
 
=head1 DESCRIPTION

This package is used to redirect scalar assignments in the config namespace to the options hash.

=cut

use Carp;

=pod

=head1 EXPORTS

None

=cut

use Exporter qw(import);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
our @EXPORT = qw(
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

=pod

=head1 FUNCTIONS

=over 4

=item TIESCALAR

Constructor

=cut

sub TIESCALAR {
  my $class  = shift;
  my $option = shift;

  return bless $option, $class;
}

=pod

=item STORE

Called for each assignment of the scalar.

=cut

sub STORE {
  my $self = shift;
  unless (eval { &{$self}($_[0]); 1 }) {
    my $errorText = $@;
    $errorText =~ s/ at .* line \d+\.$//;
    chomp $errorText;
    croak $errorText;
  }
  return &{$self}();
}

=pod

=item FETCH

Called each time the scalar is read.

=cut

sub FETCH {
  my $self = shift;
  return &{$self}();
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
