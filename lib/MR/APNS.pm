package MR::APNS;

our $VERSION = '0.01';

use Mouse;
use MR::APNS::Transport;
use MR::APNS::Payload;

has 'error'  => (
    is              => 'rw',
    isa             => 'Str',
    clearer         => 'clean_error',
    lazy            => 1,
    default         => sub { 'OK' },
    documentation   => 'connect/transport error'
);

has 'transport'  => (
    is              => 'rw',
    isa             => 'MR::APNS::Transport',
    required        => 1
);


#before ['send', 'done']

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
    $param->{transport} = MR::APNS::Transport->new($param);
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
