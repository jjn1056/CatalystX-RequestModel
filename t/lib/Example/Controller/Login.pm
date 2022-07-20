package Example::Controller::Login;

use Moose;
use MooseX::MethodAttributes;
use Data::Dumper;

extends 'Catalyst::Controller';

sub login :POST Chained(/) Args(0) Does(RequestModel) RequestModel(LoginRequest)  {
  my ($self, $c, $request) = @_;
  $c->res->body(Dumper $request->nested_params);
}

sub info :GET Chained(/) Args(0) Does(RequestModel) RequestModel(InfoQuery)  {
  my ($self, $c, $request) = @_;
  $c->res->body(Dumper $request->nested_params);
}

__PACKAGE__->meta->make_immutable;

