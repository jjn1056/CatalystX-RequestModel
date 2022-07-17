package CatalystX::RequestModel::ContentBodyParser::JSON;

use warnings;
use strict;
use base 'CatalystX::RequestModel::ContentBodyParser';

sub content_type { 'application/json' }

sub new {
  my ($class, %args) = @_;
  my $self = bless \%args, $class;
  $self->{bp} ||= $self->{ctx}->req->body_data;

  ## TODO prepare into hash of hashes to optimize how indexes work
  #use Devel::Dwarn;
  #Dwarn $self->{bp} ;

  return $self;
}

sub parse {
  my ($self, $ns, $rules) = @_;
  my %parsed = %{ $self->handle_data_encoded($self->{bp}, $ns, $rules) };
  return %parsed;
}

sub _sorted {
  return 1 if $a eq '';
  return -1 if $b eq '';
  return $a <=> $b;
}

sub handle_data_encoded {
  my ($self, $context, $ns, $rules) = @_;
  my $current = +{};

  use Devel::Dwarn;
  Dwarn [$context, $ns, $rules];

  while(@$rules) {
    my $current_rule = shift @{$rules};
    my ($attr, $attr_rules) = %$current_rule;
    my $param_name = $attr_rules->{name};
    $attr_rules = +{ flatten=>0, %$attr_rules }; ## Set defaults

    MAIN: while(@{$rules}) {
      my $rule = shift @{$rules};
      my ($local_ns, $rules) = %$rule;
      my $local_context = $context;

      foreach my $pointer (@$ns, $local_ns) {
        if(exists($local_context->{$pointer})) {
          $local_context = $local_context->{$pointer};
        } else {
          warn "missing param $pointer";
          next MAIN;
        }
      }

      if(0) {
      } else {

        Dwarn $local_context;
        #my $body_parameter_name = join '.', @$ns, (defined($index) ? "${param_name}[$index]": $param_name);
        #next unless exists $body_parameters->{$body_parameter_name};   ## TODO needs to be a proper Bad Request Exception class
        #my $value = $body_parameters->{$body_parameter_name};
        #$current->{$attr} = $self->normalize_value($body_parameter_name, $value, $attr_rules);
      }
    }
  }
  return $current;
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

1;

=head1 NAME

CatalystX::RequestModel::ContentBodyParser::FormURLEncoded - Parse HTML Form POSTS

=head1 SYNOPSIS

    TBD

=head1 DESCRIPTION

Given a flat list of HTML Form posted parameters will attempt to convert it to a hash of values,
with nested and arrays of nested values as needed.  For example you can convert something like:

    .-------------------------------------+--------------------------------------.
    | Parameter                           | Value                                |
    +-------------------------------------+--------------------------------------+
    | person.username                     | jjn                                  |
    | person.first_name [multiple]        | 2, John                              |
    | person.last_name                    | Napiorkowski                         |
    | person.password                     | abc123                               |
    | person.password_confirmation        | abc123                               |
    '-------------------------------------+--------------------------------------'

Into:

    {
      first_name => "John",
      last_name => "Napiorkowski",
      username => "jjn",
    }

Or:

    .-------------------------------------+--------------------------------------.
    | Parameter                           | Value                                |
    +-------------------------------------+--------------------------------------+
    | person.first_name [multiple]        | 2, John                              |
    | person.last_name                    | Napiorkowski                         |
    | person.person_roles[0]._nop         | 1                                    |
    | person.person_roles[1].role_id      | 1                                    |
    | person.person_roles[2].role_id      | 2                                    |
    | person.username                     | jjn                                  |
    '-------------------------------------+--------------------------------------'

Into:

    {
      first_name => "John",
      last_name => "Napiorkowski",
      username => "jjn",
      person_roles => [
        {
          role_id => 1,
        },
        {
          role_id => 2,
        },
      ],
    }

We define some settings described below to help you deal with some of the issues you find when trying
to parse HTML form posted body content.  For now please see the test cases for more examples.

=head1 VALUE PARSER CONFIGURATION

This parser defines the following attribute properties which effect how a value is parsed.

=head2 flatten

If the value associated with a field is an array, flatten it to a single value.  Its really a hack to deal
with HTML form POST and Query parameters since the way those formats work you can't be sure if a value is
flat or an array.

=head2 always_array

Similar to C<flatten> but opposite, it forces a value into an array even if there's just one value.

B<NOTE>: The attribute property settings C<flatten> and C<always_array> are currently exclusive (only one of
the two will apply if you supply both.  The C<always_array> property always takes precedence.  At some point
in the future supplying both might generate an exception so its best not to do that.  I'm only leaving it
allowed for now since I'm not sure there's a use case for both.

=head1 INDEXING

When POSTing deeply nested forms with repeated elements you can use a naming convention to indicate ordering:

    param[index]...

For example:

    .-------------------------------------+--------------------------------------.
    | Parameter                           | Value                                |
    +-------------------------------------+--------------------------------------+
    | person.person_roles[0]._nop         | 1                                    |
    | person.person_roles[1].role_id      | 1                                    |
    | person.person_roles[2].role_id      | 2                                    |
    | person.person_roles[].role_id       | 3                                    |
    '-------------------------------------+--------------------------------------'

Could convert to:

    [
      {
        role_id => 1,
      },
      {
        role_id => 2,
      },
    ]

Please note the the index value is just used for ordering purposed.  Also if you just need to add a new item
to the end of the indexed list you can use and empty index '[]' as in the example above.

=head1 HTML FORM POST ISSUES

Many HTML From input controls don't make it easy to send a default value if they are left blank.  For example
HTML checkboxes will not send a 'false' value if you leave them unchecked.  To deal with this issue you can either
set a default attribute property or you can use a hidden field to send the 'unchecked' value and rely on the
flatten option to choose the correct value.

You may also have this issue with indexed parameters if the indexed parameters are associated with a checkbox
or other control that sends no default value.  In that case you can do the same thing, either set a default
empty arrayref as the value for the attribute or send a ignored indexed parameter (as in the above example).

=head1 EXCEPTIONS

This class can throw the following exceptions:

=head2 Invalid JSON in value

If you mark an attribute as "expand=>'JSON'" and the value isn't valid JSON then we throw
an L<CatalystX::RequestModel::Utils::InvalidJSONForValue> exception which if you are using
L<CatalystX::Errors> will be converted into a HTTP 400 Bad Request response (and also logging
to the error log the JSON parsing error).


=head1 AUTHOR

See L<CatalystX::RequestModel>.
 
=head1 COPYRIGHT
 
See L<CatalystX::RequestModel>.

=head1 LICENSE
 
See L<CatalystX::RequestModel>.
 
=cut
