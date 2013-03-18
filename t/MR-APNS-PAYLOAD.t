use strict;
use warnings;

use Test::More tests => 2;
BEGIN { use_ok('MR::APNS::Payload') };

# $ee = MR::APNS::Payload->new(token => '9f19404f78b8e440d2af15767dce877be3e18f81657cc8861f370fa3311a209c', alert => "Hi APNS!")
isa();
