package Example::Model::Root::Test1Body;

use Moose;
use CatalystX::RequestModel;

extends 'Catalyst::Model';
content_type 'application/x-www-form-urlencoded';

has username => (is=>'ro', required=>1, property=>1);  
has password => (is=>'ro', property=>1);

__PACKAGE__->meta->make_immutable();
