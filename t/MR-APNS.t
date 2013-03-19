use strict;
use warnings;

use Test::More tests => 3;

use_ok('MR::APNS');
isa_ok('MR::APNS', 'Mouse::Object');
can_ok('MR::APNS', qw(error transport send retrieve_feedback ACTION_NONE ACTION_RESEND ACTION_DELETE));
