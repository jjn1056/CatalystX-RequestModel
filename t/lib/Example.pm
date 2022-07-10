package Example;

use Catalyst;
use Moose;

__PACKAGE__->setup_plugins([qw//]);
__PACKAGE__->config();

__PACKAGE__->setup();
__PACKAGE__->meta->make_immutable();
