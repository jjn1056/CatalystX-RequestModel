package CatalystX::RequestModel::ContentBodyParser;

use warnings;
use strict;
use Module::Runtime ();
use CatalystX::RequestModel::Utils::InvalidJSONForValue;

my $_JSON_PARSER;
my $_build_json_parser = sub {
  return $_JSON_PARSER ||= Module::Runtime::use_module('JSON::MaybeXS')->new(utf8 => 1);
};

sub content_type { die "Must be overridden" }

sub parse { die "Must be overridden"}

sub normalize_value {
  my ($self, $param, $value, $key_rules) = @_;

  if($key_rules->{always_array}) {
    $value = $self->normalize_always_array($value);
  } elsif($key_rules->{flatten}) {
    $value = $self->normalize_flatten($value);
  }

  $value = $self->normalize_json($value, $param) if (($key_rules->{expand}||'') eq 'JSON');
  $value = $self->normalize_boolean($value) if ($key_rules->{boolean}||'');

  return $value;
}

sub normalize_always_array {
  my ($self, $value) = @_;
  $value = [$value] unless (ref($value)||'') eq 'ARRAY';
  return $value;
}

sub normalize_flatten{
  my ($self, $value) = @_;
    $value = $value->[-1] if (ref($value)||'') eq 'ARRAY';
  return $value;
}

sub normalize_boolean {
  my ($self, $value) = @_;
  return $value ? 1:0
}

sub normalize_json {
  my ($self, $value, $param) = @_;

  eval {
    $value = $self->$_build_json_parser->decode($value);
  } || do {
    CatalystX::RequestModel::Utils::InvalidJSONForValue->throw(param=>$param, parsing_error=>$@);
  };

  return $value;
}

1;

=head1 NAME

CatalystX::RequestModel::ContentBodyParser - Content Parser base class

=head1 SYNOPSIS

    TBD

=head1 DESCRIPTION

Base class for content parsers.   Basically we need the ability to take a given POSTed
or PUTed (or PATCHed even I guess) content body and normalized it to a hash of data that
can be used to instantiate the request model.  As well you need to be able to read the 
meta data for each field and do things like flatten arrays (or inflate them, etc) and 
so forth.

This is lightly documented for now but there's not a lot of code and you can refer to the
packaged subclasses of this for hints on how to deal with your odd incoming content types.

=head1 EXCEPTIONS

This class can throw the following exceptions:

=head2 Invalid JSON in value

If you mark an attribute as "expand=>'JSON'" and the value isn't valid JSON then we throw
an L<CatalystX::RequestModel::Utils::InvalidJSONForValue> exception which if you are using
L<CatalystX::Errors> will be converted into a HTTP 400 Bad Request response (and also logging
to the error log the JSON parsing error).

=head1 METHODS

This class defines the following public API

=head2

=head1 AUTHOR

See L<CatalystX::RequestModel>.
 
=head1 COPYRIGHT
 
See L<CatalystX::RequestModel>.

=head1 LICENSE
 
See L<CatalystX::RequestModel>.
 
=cut
