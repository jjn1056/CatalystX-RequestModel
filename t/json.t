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
  ok my $data = qq[
    {
      "person":{
        "username": "jjn",
        "first_name": "john",
        "last_name": "napiorkowski"
      }
    }
  ];

  ok my $res = request POST '/account/json',
    Content_Type => 'application/json',
    Content => $data;

  ok my $data =  $res->content; 

  warn $data;
}

done_testing;

__END__


