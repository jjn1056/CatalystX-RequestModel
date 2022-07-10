package CatalystX::RequestModel;

our $VERSION = '0.001';

use Class::Method::Modifiers;
use Scalar::Util;
use Moo::_Utils;
use Module::Pluggable::Object;
use Module::Runtime ();
use CatalystX::RequestModel::Utils::InvalidContentType;

require Moo::Role;
require Sub::Util;

our @DEFAULT_ROLES = (qw(CatalystX::RequestModel::DoesRequestModel));
our @DEFAULT_EXPORTS = (qw(property properties namespace content_type));
our %Meta_Data = ();
our %ContentBodyParsers = ();

sub default_roles { return @DEFAULT_ROLES }
sub default_exports { return @DEFAULT_EXPORTS }
sub request_model_metadata { return %Meta_Data }
sub request_model_metadata_for { return $Meta_Data{shift} }
sub content_body_parsers { return %ContentBodyParsers }

sub content_body_parser_for {
  my $ct = shift;
  return $ContentBodyParsers{$ct} || CatalystX::RequestModel::Utils::InvalidContentType->throw(ct=>$ct);
}

sub load_content_body_parsers {
  my $class = shift;
  my @packages = Module::Pluggable::Object->new(
      search_path => "${class}::ContentBodyParser"
    )->plugins;

  %ContentBodyParsers = map {
    $_->content_type => $_;
  } map {
    Module::Runtime::use_module $_;
  } @packages;
}

sub import {
  my $class = shift;
  my $target = caller;

  $class->load_content_body_parsers;

  unless (Moo::Role->is_role($target)) {
    my $orig = $target->can('with');
    Moo::_Utils::_install_tracked($target, 'with', sub {
      unless ($target->can('request_metadata')) {
        $Meta_Data{$target}{'request'} = \my @data;
        my $method = Sub::Util::set_subname "${target}::request_metadata" => sub { @data };
        no strict 'refs';
        *{"${target}::request_metadata"} = $method;
      }
      &$orig;
    });
  } 

  foreach my $default_role ($class->default_roles) {
    next if Role::Tiny::does_role($target, $default_role);
    Moo::Role->apply_roles_to_package($target, $default_role);
    foreach my $export ($class->default_exports) {
      Moo::_Utils::_install_tracked($target, "__${export}_for_exporter", \&{"${target}::${export}"});
    }
  }

  my %cb = map {
    $_ => $target->can("__${_}_for_exporter");
  } $class->default_exports;

  foreach my $exported_method (keys %cb) {
    my $sub = sub {
      if(Scalar::Util::blessed($_[0])) {
        return $cb{$exported_method}->(@_);
      } else {
        return $cb{$exported_method}->($target, @_);
      }
    };
    Moo::_Utils::_install_tracked($target, $exported_method, $sub);
  }

  Class::Method::Modifiers::install_modifier $target, 'around', 'has', sub {
    my $orig = shift;
    my ($attr, %opts) = @_;

    my $predicate;
    unless($opts{required}) {
      $predicate = $opts{predicate} = "has_${attr}" unless exists($opts{predicate});
    }

    if(my $info = delete $opts{property}) {
      $info = +{ name=>$attr } unless (ref($info)||'') eq 'HASH';
      $info->{attr_predicate} = $predicate if defined($predicate);
      $info->{omit_empty} = 1 unless exists($info->{omit_empty});
      my $method = \&{"${target}::property"};
      $method->($attr, $info, \%opts);
    }

    return $orig->($attr, %opts);
  } if $target->can('has');
} 

sub _add_metadata {
  my ($target, $type, @add) = @_;
  my $store = $Meta_Data{$target}{$type} ||= do {
    my @data;
    if (Moo::Role->is_role($target) or $target->can("${type}_metadata")) {
      $target->can('around')->("${type}_metadata", sub {
        my ($orig, $self) = (shift, shift);
        ($self->$orig(@_), @data);
      });
    } else {
      require Sub::Util;
      my $method = Sub::Util::set_subname "${target}::${type}_metadata" => sub { @data };
      no strict 'refs';
      *{"${target}::${type}_metadata"} = $method;
    }
    \@data;
  };

  push @$store, @add;
  return;
}

=head1 NAME

CatalystX::RequestModel - Inflate Models from a Request Content Body

=head1 SYNOPSIS

An example Catalyst Model:

    package Example::Model::RegistrationRequest;

    use Moose;
    use CatalystX::RequestModel;

    extends 'Catalyst::Model';

    namespace 'person';
    content_type 'application/x-www-form-urlencoded';

    has username => (is=>'ro', property=>1);   
    has first_name => (is=>'ro', property=>1);
    has last_name => (is=>'ro', property=>1);
    has password => (is=>'ro', property=>1);
    has password_confirmation => (is=>'ro', property=>1);

    __PACKAGE__->meta->make_immutable();

Using it in a controller:

    package Example::Controller::Register;

    use Moose;
    use MooseX::MethodAttributes;

    extends 'Catalyst::Controller';

    sub root :Chained(/root) PathPart('register') CaptureArgs(0)  { }

    sub update :POST Chained('root') PathPart('') Args(0) Does(RequestModel) RequestModel(RegistrationRequest) {
      my ($self, $c, $request_model) = @_;
      ## Do something with the $request_model
    }

    __PACKAGE__->meta->make_immutable;

Now if the incoming POST looks like this:

    .-------------------------------------+--------------------------------------.
    | Parameter                           | Value                                |
    +-------------------------------------+--------------------------------------+
    | person.username                     | jjn                                  |
    | person.first_name [multiple]        | 2, John                              |
    | person.last_name                    | Napiorkowski                         |
    | person.password                     | abc123                               |
    | person.password_confirmation        | abc123                               |
    '-------------------------------------+--------------------------------------'

The object instance C<$request_model> would look like:

    say $request_model->username;       # jjn
    say $request_model->first_name;     # John
    say $request_model->last_name;      # Napiorkowski

And C<$request_model> has additional helper public methods to query attributes marked as request
fields (via the C<property> attribute field) which you can read about below.

=head1 DESCRIPTION

Dealing with incoming POSTed (or PUTed/ PATCHed, etc) content bodies is one of the most common
code issues we have to deal with.  L<Catalyst> has generic capacities for handling common incoming
content types such as form URL encoded (common with HTML forms) and JSON as well as the ability to
add in parsing for other types of contents (see L<Catalyst#DATA-HANDLERS>).   However these parsers
only checked that a given body content is well formed and not that its valid for your given problem
domain.  Additionally I find that we spend a lot of code lines in controllers that are doing nothing
but munging and trying to wack incoming parameters into a form that can be actually used.

I've seen this approach of mapping incoming content bodies to models put to good use in frameworks
in other languages.  Mapping to a model gives you a clear place to do any data reformating you
need as well as the type of pre validation work we often perform in a controller.  Think of it as a
type of command class pattern subtype.  It promotes looser binding between your controller and your
applications models, and it makes for neater, smaller controllers as well as separating out the
types of work we do into smaller, more comprehendible classes.   Lastly we encapsulate some of the
more common types of issues into configuration (for example dealing with how HTML form POSTed
parameters can cause you issues when there are sometimes in array form) as well as improve security
by having an explict interface to the model.

Also once we have a model that defines an expected request, we should be able to build upon the meta data
it exposed to do things like auto generate Open API / JSON Schema definition files (TBD but possible).

The main downside here is the time you need to inflate the additional classes as well as some documentation
efforts needed to help new programmers understand this approach.

If you hate this idea but still like the thought of having more structure in mapping your incoming
random parameters you might want to check out L<Catalyst::TraitFor::Request::StructuredParameters>.

=head2 Endpoints with more than one request model

If an endpoint can handle more than one type of incoming content type you can define that
via the subroutine attribute and the code will pick the right one or throw an exception if none match
(See L</EXCEPTIONS> for more).

    sub update :POST Chained('root') PathPart('') Args(0) 
      Does(RequestModel) 
      RequestModel(RegistrationRequestForm) 
      RequestModel(RegistrationRequesJSON)
    {
      my ($self, $c, $request_model) = @_;
      ## Do something with the $request_model
    }

=head1 METHODS

Please see L<CatalystX::RequestModel::DoesRequestModel> for the public API details

=head1 EXCEPTIONS

This class can throw the following exceptions:

=head2 Invalid Request Content Type

If the incoming content body doesn't have a content type header that matches one of the available
content body parsers then we throw an L<CatalystX::RequestModel::Utils::InvalidContentType>.  This
will get interpretated as an HTTP 415 status client error if you are using L<CatalystX::Errors>.

=head1 AUTHOR

    John Napiorkowski <jjnapiork@cpan.org>

=head1 COPYRIGHT
 
    2022

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
 
=cut

