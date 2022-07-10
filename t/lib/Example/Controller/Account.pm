package Example::Controller::Account;

use Moose;
use MooseX::MethodAttributes;
use Data::Dumper;

extends 'Catalyst::Controller';

sub root :Chained(/) PathPart('account') CaptureArgs(0) { }

  sub one :Chained(root) PathPart('one') Args(0) Does(RequestModel) RequestModel(AccountRequest) {
    my ($self, $c, $request) = @_;
    $c->res->body(Dumper $request->nested_params);
  }

__PACKAGE__->meta->make_immutable;

