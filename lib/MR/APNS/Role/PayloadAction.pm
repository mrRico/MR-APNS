package MR::APNS::Role::PayloadAction;
use Mouse::Role;
use List::Util qw();

use vars qw(@NEED_RESEND @SENDED);

@NEED_RESEND = qw(
    PAYLOAD_CREATE
    TRANSPORT_TIMEOUT
);

@SENDED = qw(
    PAYLOAD_SEND
    APNS_NO_ERRORS
);

requires qw(error_str);

sub need_action {
    my $error_str = shift->error_str;
    if (List::Util::first { $error_str eq $_ } @SENDED) {
        return MR::APNS::ACTION_NONE();
    } elsif (List::Util::first { $error_str eq $_ } @NEED_RESEND) {
        return MR::APNS::ACTION_RESEND();
    } else {
        return MR::APNS::ACTION_DELETE();
    };
}

1;
__END__
