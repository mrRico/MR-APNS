package MR::APNS;

our $VERSION = '0.01';

use Mouse;
use MR::APNS::Transport;
use MR::APNS::Payload;

use Exporter qw(import);
use vars     qw(@EXPORT @EXPORT_OK %EXPORT_TAGS);

@EXPORT      = qw();
@EXPORT_OK   = qw(ACTION_NONE ACTION_RESEND ACTION_DELETE);
%EXPORT_TAGS = (
    action => [qw(ACTION_NONE ACTION_RESEND ACTION_DELETE)]
);

use constant {
    ACTION_NONE     => 0,
    ACTION_RESEND   => 1,
    ACTION_DELETE   => 2
};

has 'error'  => (
    is              => 'rw',
    isa             => 'Str',
    clearer         => 'clean_error',
    lazy            => 1,
    default         => sub { '' },
    documentation   => 'connect/transport error'
);

has 'transport'  => (
    is              => 'rw',
    isa             => 'MR::APNS::Transport',
    required        => 1
);


sub send {
    my $self = shift;
    $self->clean_error();
    my @messages = ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_;
    return 0 unless @messages;
    
    my ($send_cnt, $error) = $self->transport->send(@messages);
    $self->error($error) if $error;
    return $send_cnt;
}

sub BUILDARGS {
    my $class = shift;
    my $param = @_==1 ? $_[0] : {@_};
    $param->{transport} ||= MR::APNS::Transport->new($param);
    return $param; 
}

sub BUILD {
    my $self = shift;
    return $self->transport ? $self : undef;
}

__PACKAGE__->meta->make_immutable;
no Mouse;
1;
__END__

=head1 NAME

MR::APNS - Apple Push Notifications Service (APNS) client with enhanced format for notification packets.

=head1 SYNOPSIS

    use MR::APNS qw(:action);
    
    my $token       = "9f19404f78b8e440d2af15767dce877be3e18f81657cc8861f370fa3311a2077";
    my $bin_token   = pack 'H*', $device_token;
    
    my @m = (  
        MR::APNS::Payload->new(token => $token, alert => 'My first message'),
        MR::APNS::Payload->new(bintoken => $bin_token, alert => 'My second message')
    );
    
    my $apns = MR::APNS->new(
        sandbox => 1,
        cert_file => '/path/to/cert.pem'
    );
    
    my $send_cnt = $apns->send(@m);
    
    if ($apns->error or $send_cnt != @m) {
        for (@m) {
            my $action = $_->need_action;
            if ($action == ACTION_NONE) {
                # success
                print "message already send\n";
            } elsif ($action == ACTION_RESEND) {
                # timeout or unsended because transport error
                print "message need to resend (error: ".$_->error_str.")\n";
            } elsif ($action == ACTION_RESEND) {
                # don't try to resend
                print "message malformed (error: ".$_->error_str.")\n";
            }
        }
        # transport error
        die $apns->error if $apns->error;
    }

=head1 DESCRIPTION

meow..

=cut
