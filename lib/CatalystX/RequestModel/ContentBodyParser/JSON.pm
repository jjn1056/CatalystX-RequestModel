package CatalystX::RequestModel::ContentBodyParser::JSON;

use warnings;
use strict;
use base 'CatalystX::RequestModel::ContentBodyParser';

sub content_type { 'application/json' }

sub new {
  my ($class, %args) = @_;
  my $self = bless \%args, $class;
  $self->{context} ||= $self->{ctx}->req->body_data;

  return $self;
}

sub parse {
  my ($self, $ns, $rules) = @_;
  my %parsed = %{ $self->handle_data_encoded($self->{context}, $ns, $rules) };
  return %parsed;
}

sub handle_data_encoded {
  my ($self, $context, $ns, $rules, $indexed) = @_;
  my $response = +{};

  # point $context to the namespace or die if not a valid namespace
  foreach my $pointer (@$ns) {
    if(exists($context->{$pointer})) {
      $context = $context->{$pointer};
    } else {
      die "invalid request does not contain the namespace @$ns";  ## TODO real exception errror
    }
  }

  while(@$rules) {
    my $current_rule = shift @{$rules};
    my ($attr, $attr_rules) = %$current_rule;
    my $data_name = $attr_rules->{name};
    $attr_rules = +{ flatten=>0, %$attr_rules }; ## Set defaults

    next unless exists $context->{$data_name}; # required handled by Moo/se required attribute

    if( !$indexed && $attr_rules->{indexed}) {

      die "Value of indexed request field is not an array"
        unless ((ref($context->{$data_name})||'') eq 'ARRAY'); ## TODO real exception errror

      my @response_data;
      foreach my $indexed_value(@{$context->{$data_name}}) {
        my $indexed_response = $self->handle_data_encoded(+{ $data_name => $indexed_value}, [], [$current_rule], 1);
        push @response_data, $indexed_response->{$data_name};
      }

      if(@response_data) {
        $response->{$data_name} = \@response_data;
      } elsif(!$attr_rules->{omit_empty}) {
        $response->{$data_name} = [];
      }

    } elsif(my $nested_model = $attr_rules->{model}) { 
        $response->{$attr} = $self->{ctx}->model(
          $self->normalize_nested_model_name($nested_model), 
          current_parser=>$self,
          context=>$context->{$data_name},
        );
    } else {
      my $value = $context->{$data_name};
      $response->{$data_name} = $self->normalize_value($data_name, $value, $attr_rules);
    }
  }

  return $response;
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

CatalystX::RequestModel::ContentBodyParser::JSON

=head1 SYNOPSIS

    TBD

=head1 DESCRIPTION

Given a valid JSON request body, parse it and inflate request models as defined or throw various
exceptions otherwise.  for example given the following nested request models:

    package Example::Model::API::AccountRequest;

    use Moose;
    use CatalystX::RequestModel;

    extends 'Catalyst::Model';
    namespace 'person';
    content_type 'application/json';

    has username => (is=>'ro', property=>1);  
    has first_name => (is=>'ro', property=>1);
    has last_name => (is=>'ro', property=>1);
    has profile => (is=>'ro', property=>+{model=>'API::AccountRequest::Profile' });
    has person_roles => (is=>'ro', property=>+{ indexed=>1, model=>'API::AccountRequest::PersonRole' });
    has credit_cards => (is=>'ro', property=>+{ indexed=>1, model=>'API::AccountRequest::CreditCard' });

    __PACKAGE__->meta->make_immutable();

    package Example::Model::API::AccountRequest::Profile;

    use Moose;
    use CatalystX::RequestModel;

    extends 'Catalyst::Model';

    has id => (is=>'ro', property=>1);
    has address => (is=>'ro', property=>1);
    has city => (is=>'ro', property=>1);
    has state_id => (is=>'ro', property=>1);
    has zip => (is=>'ro', property=>1);
    has phone_number => (is=>'ro', property=>1);
    has birthday => (is=>'ro', property=>1);
    has registered => (is=>'ro', property=>+{ boolean=>1 });

    __PACKAGE__->meta->make_immutable();

    package Example::Model::API::AccountRequest::PersonRole;

    use Moose;
    use CatalystX::RequestModel;

    extends 'Catalyst::Model';

    has role_id => (is=>'ro', property=>1);

    __PACKAGE__->meta->make_immutable();

    package Example::Model::API::AccountRequest::CreditCard;

    use Moose;
    use CatalystX::RequestModel;

    extends 'Catalyst::Model';

    has id => (is=>'ro', property=>1);
    has card_number => (is=>'ro', property=>1);
    has expiration => (is=>'ro', property=>1);

    __PACKAGE__->meta->make_immutable();

And the following POSTed JSON request body:

    {
      "person":{
        "username": "jjn",
        "first_name": "john",
        "last_name": "napiorkowski",
        "profile": {
          "id": 1,
          "address": "1351 Miliary Road",
          "city": "Little Falls",
          "state_id": 7,
          "zip": "42342",
          "phone_number": 6328641827,
          "birthday": "2222-01-01",
          "registered": false        
        },
        "person_roles": [
          { "role_id": 1 },
          { "role_id": 2 }
        ],
        "credit_cards": [
          { "id":100, "card_number": 111222333444, "expiration": "2222-02-02" },
          { "id":200, "card_number": 888888888888, "expiration": "3333-02-02" },
          { "id":300, "card_number": 333344445555, "expiration": "4444-02-02" }
        ]
      }
    }

Will inflate a request model that provides:

    my $request_model = $c->model('API::AccountRequest');
    Dumper $request_model->nested_model;

    +{
      'person_roles' => [
                          {
                            'role_id' => 1
                          },
                          {
                            'role_id' => 2
                          }
                        ],
      'profile' => {
                     'address' => '1351 Miliary Road',
                     'birthday' => '2222-01-01',
                     'id' => 1,
                     'state_id' => 7,
                     'phone_number' => 6328641827,
                     'registered' => 0,
                     'zip' => '42342',
                     'city' => 'Little Falls'
                   },
      'credit_cards' => [
                          {
                            'card_number' => '111222333444',
                            'expiration' => '2222-02-02',
                            'id' => 100
                          },
                          {
                            'id' => 200,
                            'card_number' => '888888888888',
                            'expiration' => '3333-02-02'
                          },
                          {
                            'id' => 300,
                            'card_number' => '333344445555',
                            'expiration' => '4444-02-02'
                          }
                        ],
      'first_name' => 'john',
      'username' => 'jjn',
      'last_name' => 'napiorkowski' 
    };    

__PACKAGE__->meta->make_immutable();

=head1 VALUE PARSER CONFIGURATION

This parser defines the following attribute properties which effect how a value is parsed.

=head2 flatten

Defaults to false.  If enabled it will flatten an array value to a scalar which is the value of the
last item in the list. Probably not useful in JSON, it's more of a hack for HTML Form posts, which
makes it hard to be consistent in array versus scalar values, but no reason to not offer the feature
if you need it.

=head2 always_array

Similar to C<flatten> but opposite, it forces a value into an array even if there's just one value.  Also
defaults to FALSE.

=head1 EXCEPTIONS

This class can throw the following exceptions:

=head2 Invalid JSON in value

If you mark an attribute as "expand=>'JSON'" and the value isn't valid JSON then we throw
an L<CatalystX::RequestModel::Utils::InvalidJSONForValue> exception which if you are using
L<CatalystX::Errors> will be converted into a HTTP 400 Bad Request response (and also logging
to the error log the JSON parsing error).

Not sure why you'd need this for JSON request bodies but again no reason for me to disable the option
I guess.

=head1 AUTHOR

See L<CatalystX::RequestModel>.
 
=head1 COPYRIGHT
 
See L<CatalystX::RequestModel>.

=head1 LICENSE
 
See L<CatalystX::RequestModel>.
 
=cut
