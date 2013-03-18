package MR::APNS::Payload;
use Mouse;
use JSON::XS qw();
use Encode qw();
use bytes;

with qw(
    MR::APNS::Role::PayloadError
    MR::APNS::Role::PayloadAction
);

# you can set either token or bintoken
has 'token'  => (
    is              => 'ro',
    isa             => 'Str',
    required        => 1 
);

has 'bintoken'  => (
    is              => 'ro',
    isa             => 'Str',
    required        => 1 
);

has 'alert'  => (
    is              => 'rw',
    isa             => 'Str|HashRef',
    predicate       => 'has_alert'
);

around 'alert' => sub {
    my $orig = shift;
    my $self = shift;
    return $self->$orig(@_) unless (@_ and $self->_utf8_on);
    
    my $alert = @_ == 1 ? $_[0] : {@_};
    unless (ref $alert) {
        Encode::_utf8_on($alert);
    } else {
        Encode::_utf8_on($alert->{body}) if exists $alert->{body};
        if (exists $alert->{'loc-args'}) {
            Encode::_utf8_on($_) for @{$alert->{'loc-args'}};
        } 
    }
    return $self->$orig($alert);
};

has 'badge'  => (
    is              => 'rw',
    isa             => 'Int',
    predicate       => 'has_badge'
);

has 'sound'  => (
    is              => 'rw',
    isa             => 'Str',
    predicate       => 'has_sound'
);

has 'custom'  => (
    is              => 'rw',
    isa             => 'Maybe[HashRef]',
    clearer         => 'clean_custom',
    documentation   => 'any additional dictory'
);

has 'expiry'  => (
    is              => 'rw',
    isa             => 'Int',
    lazy            => 1,
    default         => sub { 0 },
    documentation   => 'Date expressed in seconds (UTC) that identifies when the notification is no longer valid and can be discarded'
);

has 'error'  => (
    is              => 'rw',
    isa             => 'PayloadError',
    lazy            => 1,
    default         => sub { -1 },
    documentation   => 'error code. see also MR::APNS::Role::PayloadError'
);

has 'context'  => (
    is              => 'rw',
    isa             => 'Any',
    lazy            => 1,
    default         => sub { undef },
    documentation   => 'anything that can help to relate this instance with another code'    
);

has '_can_skip_custom'  => (
    is              => 'rw',
    isa             => 'Bool',
    lazy            => 1,
    default         => sub { 0 },
    documentation   => 'try to skip custom when payload is too big'
);

has '_identifier'  => (
    is              => 'ro',
    isa             => 'Int',
    lazy            => 1,
    default         => sub { hex(["$_[0]"=~/\((0x[0-9a-f]+)\)/]->[0]) },
    documentation   => 'This same identifier is returned in a error-response packet if APNs cannot interpret a notification.'
);

has '_utf8_on'  => (
    is              => 'ro',
    isa             => 'Bool',
    required        => 1,
    default         => sub { 0 },
    documentation   => 'utf8 flag up for alert (simple alert, or "body" and "loc-args" keys)'
);

has 'as_binary'  => (
    is              => 'rw',
    isa             => 'Maybe[Str]',
    lazy            => 1,
    default         => sub {
        my $self = shift;
        my $json = $self->custom || {};
        
        my $not_empty = 0;
        for ( qw(alert badge sound) ) {
            my $predicate = 'has_'.$_;
            if ($self->$predicate) {
                $json->{aps}->{$_} = $self->$_;
                $not_empty ||= 1;
            }
        }
        return unless $not_empty;
        
        $json = JSON::XS->new->utf8->encode($json);
        if (bytes::length $json > 256) {
            if ($self->custom and $self->_can_skip_custom) {
                $self->clean_custom;
                return $self->to_bin;
            } else {
                $self->error(-7);
                return;
            }
        }
        
        return pack(
            'C L N n/a* n/a*',
            1,
            $self->_identifier,
            $self->expiry,
            $self->bintoken,
            $json
        );        
    },
    documentation   => 'payload to send'
);

sub BUILDARGS {
    my $class = shift;
    my $param = @_==1 ? $_[0] : {@_};
    if ($param->{token} and not $param->{bintoken}) {
        $param->{bintoken} = pack('H*', $param->{token});
    } elsif ($param->{bintoken} and not $param->{token}) {
        $param->{token} = unpack('H*', $param->{bintoken});
    };
    return $param; 
}

sub BUILD {
    my $self = shift;
    # utf8 up
    $self->alert($self->alert) if $self->_utf8_on;
    return $self;
}

__PACKAGE__->meta->make_immutable;
no Mouse;
1;
__END__
=head1 NAME

MR::APNS::Payload - push notification instance

=head1 DESCRIPTION

It's L<Mouse> class

=head1 ATTRIBUTES

=head3 Required

=over

=item token : Str (ro)

=item bintoken : Str (ro)

It's device token. Use either of them.

=back

=head3 Optional

=over

=item alert : Str:HashRef (rw)

Message

=item badge : Int (rw)

The number to display as the badge of the application icon.
To remove the badge, set the value of this property to 0.

=item sound : Str (rw)

The name of a sound file in the application bundle. 
The sound in this file is played as an alert. 
If the sound file doesn't exist or I<default> is specified as the value, the default alert sound is played.

=item custom : HashRef (rw)

Custom dictionary which need include to payload.

=item _can_skip_custom : Bool (rw)

When payload has size more than 256 byte, it's able to skip custom dictionary. B<Default>: 0

=item expiry : Int (rw)

Date expressed in seconds (UTC) that identifies when the notification is no longer valid and can be discarded. B<Default>: 0

=item error : Int (rw)

=item error_str : Str (rw)

See source code L<MR::APNS::Role::PayloadError>. In common case use L<error_str>.

=item context : Any (rw)

Anything that can help to relate this instance with another code

=item  _identifier : Int (ro)

The first rule of C<_identifier> is: You do not talk about C<_identifier>.

=item _utf8_on : Bool (ro)

Invoke C<Encode::_utf8_on> on simple alert or "body" and "loc-args" keys.

=back

=head1 METHODS

=head2 as_binary()

Make payload

=head1 SEE ALSO and DEPENDENCIES

L<MR::APNS>

=head1 LICENSE

This library is under meow license.

=cut