BEGIN {
  use Test::Most;
  eval "use Catalyst 5.90090; 1" || do {
    plan skip_all => "Need a newer version of Catalyst => $@";
  };
}

use Test::Lib;
use HTTP::Request::Common;
use Catalyst::Test 'Example';

{
  ok my $body_parameters = [
    'person.first_name' => 2,
    'person.first_name' => 'John', # flatten array should just pick the last one
    'person.last_name' => 'Napiorkowski',
    'person.username' => 'jjn',
    'person.notes' => '{"test":"one", "foo":"bar"}',
    'person.maybe_array' => 'one',
    'person.maybe_array2' => 'one',
    'person.maybe_array2' => 'two',
    'person.profile.address' => '15604 Harry Lind Road',
    'person.profile.birthday' => '2000-01-01',
    'person.profile.city' => 'Elgin',
    'person.profile.id' => 1,
    'person.profile.phone_number' => 16467081837,
    'person.profile.registered' => 0,
    'person.profile.registered' => 'sdfsdfsdfsd',
    'person.profile.state_id' => 2,
    'person.profile.status' => '',
    'person.profile.status' => 'pending',
    'person.profile.zip' => 78621,
    'person.credit_cards[0]._delete' => 0,
    'person.credit_cards[0].card_number' => 123123123123123,
    'person.credit_cards[0].expiration' => '3000-01-01',
    'person.credit_cards[0].id' => 1,
    'person.credit_cards[1]._delete' => 0,
    'person.credit_cards[1].card_number' => 4444445555556666,
    'person.credit_cards[1].expiration' => '4000-01-01',
    'person.credit_cards[1].id' => 2,
    'person.credit_cards[1]._delete' => 0,
    'person.credit_cards[].card_number' => 88888889999999,
    'person.credit_cards[].expiration' => '5000-01-01',
    'person.credit_cards[].id' => 3,
    'person.person_roles[0]._nop' => 1,
    'person.person_roles[1].role_id' => 1,
    'person.person_roles[2].role_id' => 2, 
  ];

  ok my $res = request POST '/account/one', $body_parameters;
  ok my $data = eval $res->content;  

  use Devel::Dwarn;
  Dwarn $data;
}

{
  ok my $body_parameters = [
    'person.first_name' => 2,
    'person.first_name' => 'John', # flatten array should just pick the last one
    'person.last_name' => 'Napiorkowski',
    'person.username' => 'jjn',
    'person.notes' => '{"test":"one", "foo":"bar"}',
    'person.maybe_array' => 'one',
    'person.maybe_array2' => 'one',
    'person.maybe_array2' => 'two',
    'person.person_roles[0]._nop' => 1,
    'person.person_roles[1].role_id' => 1,
    'person.person_roles[2].role_id' => 2, 
  ];

  ok my $res = request POST '/account/one', $body_parameters;
  ok my $data = eval $res->content;  

  use Devel::Dwarn;
  Dwarn $data;
}

done_testing;

__END__


