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

sub feedback {
    my $self = shift;
    $self->clean_error();
    my ($feedback, $error) = $self->transport->get_feedback;
    $self->error($error) if $error;
    return $feedback;
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
=encoding utf-8

=head1 NAME

MR::APNS - easy way to send push notification with enhanced format for packets

=head1 SYNOPSIS

=head3 sending push notifications

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
            } elsif ($action == ACTION_DELETE) {
                # don't try to resend
                print "message malformed (error: ".$_->error_str.")\n";
            }
        }
        # transport error
        die $apns->error if $apns->error;
    }

=head3 retrieve feedback

    use MR::APNS;
    
    my $apns = MR::APNS->new(
        sandbox => 1,
        cert_file => '/path/to/cert.pem'
    );
    
    while (1) {
        my $feedback = $fapns->retrieve_feedback;
        if ($feedback) {
            .. to forget about device tokens ..
        };
        die $fapns->error if $fapns->error;
        last unless $feedback;
    }

=head1 DESCRIPTION

It's a very gentle APNS (Apple Push Notifications Service) client with enhanced format for notification packets.

=head1 METHODS

=head2 new(%args)

create a new instance of C<MR::APNS::Transport> and C<MR::APNS>.

=head3 Required arguments are

=over

=item cert_file : file path (ro)

=item cert : Str (ro)

Either of them is required. Sets certificate. When C<cert> was specified then C<cert_file> will be ignored.

=back

=head3 Optional arguments are

=over

=item key_file : file path(ro)

=item key : Str(ro)

=item password : Str|CodeRef(ro)

Private key settings. B<Default> : is the same as C<cert_file>

=item sandbox : Bool(ro)

Gateway target. B<Default> : 0

=item hostname : Str(ro)

Gateway target. B<Default>: depends on C<sandbox>

=item port : Int(ro)

Gateway target. B<Default> : 2195

=item write_timeout : Num(rw)

It's timeout for L<IO::Select> to I<can_write>. It'll be invoked before sending every payload. B<Default>: 0.1

=item last_read_timeout : Num(rw)

It's timeout for L<IO::Select> to I<can_read>. It'll be invoked after sending last payload to receive error-response packets.

Between sending payloads I<can_read> invoke with zero timeout.  B<Default>: 0.1

=back

=head2 send(@messages)

Send notification for APNS. It take a list of L<MR::APNS::Payload> instances. Returns the number of success sended items.

=head2 retrieve_feedback()

Retrieve data from APNS feedback service. Returns an arrayref (possibly) containing hashrefs. eg:

    [
        {
            'time_t' => 1259577923,
            'token' => '04ef31c86205...624f390ea878416',
            'bintoken' => '..binary representation of token..'
        },
        ...
    ]

It's possibly to have feedback and C<error> at the same time when error happens on disconnect.

=head2 error

Last transport error as string.

=head2 transport

Read only access to C<MR::APNS::Transport> instance. C<MR::APNS::Transport> doesn't have a POD.
 
Avaliable state are (see above) C<cert_file>, C<cert>, C<key_file>, C<key>, C<password>, C<sandbox>, C<hostname>, C<port>, 
C<write_timeout>, C<last_read_timeout>, C<feedback> and a few methods are C<connect>, C<disconnect>, C<send>, C<get_feedback>.

In common case you don't need direct access to C<transport> 

=head1 EXPORT TAGS

=head2 :action

After sending it is possible to filter messages to receive next action need to do.

=over

=item ACTION_NONE

Message was pushed.

=item ACTION_RESEND

Transport returned timeout error or connection was interrupted.

=item ACTION_DELETE

Message is malformed

=back

=head1 MORE EXAMPLES

=head3 specify 'context' is very useful

    # 'context' has type 'Any'
    my $m = MR::APNS::Payload->new(token => $token, ..., context => $mysql_id);
    
    # in common case you shouldn't to send single notification otherwise APNS will be unhappy
    unless ( $apns->send($m) ) {
        my $action = $m->need_action;
        if ($action == ACTION_RESEND) {
            print "message with ".$m->context." need to resend (error: ".$m->error_str.")\n";
            ...
        } elsif ($action == ACTION_DELETE) {
            print "message with ".$m->context." is malformed (error: ".$m->error_str.")\n";
        }
    };

=head3 up 'utf8' flag  
    
It's case when you send utf8 alert whitout utf8 flag.

    use Encode;
    my $alert = "Привет, APNS";
    print Encode::is_utf8($alert) ? 'on' : 'off'; # off
    # or
    $alert = { body => $alert, loc-args => [...], ... };
    
    # device should receive correct message
    my $m = MR::APNS::Payload->new(token => $token, ..., _utf8_on => 1);

=head1 NOTE

I<cert_file> and I<key_file> are the same file if you've generated them as in example L<http://stackoverflow.com/questions/11536587/creating-pem-file-for-push-notification>.

=head1 SEE ALSO

L<MR::APNS::Payload>

=head1 ALL DEPENDENCIES

L<Mouse>, L<Mouse::Role>, L<Mouse::Util::TypeConstraints>, L<File::Temp>, L<IO::Select>, L<Net::SSLeay>, 
L<JSON::XS>, L<Encode>, L<List::Util>

=head1 LICENSE

This library is under meow license.

=cut
