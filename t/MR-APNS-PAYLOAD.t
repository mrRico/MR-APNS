use strict;
use warnings;

use Test::More tests => 11;

use_ok('MR::APNS::Payload');
isa_ok('MR::APNS::Payload', 'Mouse::Object');
can_ok('MR::APNS::Payload', qw(token bintoken alert badge sound custom expiry error context _can_skip_custom _identifier _utf8_on as_binary));
my $token = '9f19404f78b8e440d2af15767dce877be3e18f81657cc8861f370fa3311a2077';
my $m = MR::APNS::Payload->new(bintoken => pack('H*', $token), alert => "Hi APNS!");
isa_ok($m, 'Mouse::Object');
is($m->does('MR::APNS::Role::PayloadError'), 1, "MR::APNS::Role::PayloadError accepted");
is($m->does('MR::APNS::Role::PayloadAction'), 1, "MR::APNS::Role::PayloadAction accepted");
is($m->token, $token, "pack-unpack token");
is($m->alert, "Hi APNS!", "alert access");
is($m->has_badge || 0, 0, "default badge");
my $context = { test => 'one' };
$m->context($context);
is ($m->context, $context, "context as ref");
$context = "test";
$m->context($context);
is ($m->context, $context, "context as string");
