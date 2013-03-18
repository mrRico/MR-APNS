package MR::APNS::Role::PayloadError;
use Mouse::Role;
use Mouse::Util::TypeConstraints;

use vars qw($ERROR);

$ERROR = {
   0    => 'APNS_NO_ERRORS',
   1    => 'APNS_PROCESSING_ERROR',
   2    => 'APNS_MISSING_DEVICE_TOKEN',
   3    => 'APNS_MISSING_TOPIC',
   4    => 'APNS_MISSING_PAYLOAD',
   5    => 'APNS_INVALID_TOKEN_SIZE',
   6    => 'APNS_INVALID_TOPIC_SIZE',
   7    => 'APNS_INVALID_PAYLOAD_SIZE',
   8    => 'APNS_INVALID_TOKEN',
   255  => 'APNS_UNKNOWN_ERROR',

   -1   => 'PAYLOAD_CREATE',
   -2   => 'PAYLOAD_SEND',
   -7   => 'PAYLOAD_INVALID_SIZE',
   -255 => 'TRANSPORT_UNKNOWN_ERROR'
};

enum 'PayloadError'  => ( keys %$ERROR );

sub error_str {
    my $self = shift;
    return $ERROR->{ $self->error };
}

no Mouse::Util::TypeConstraints;
1;
__END__
