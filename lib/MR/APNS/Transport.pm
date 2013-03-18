package MR::APNS::Transport;
use Mouse;

use File::Temp  qw();
use IO::Select  qw();
use Socket      qw();
use Net::SSLeay qw();
use Carp        qw();
use IO::Handle  qw();

has 'cert_file' => (
    is              => 'ro',
    isa             => 'Str',
    predicate       => 'has_cert_file',
    documentation   => 'cart .pem file'
);

has 'key_file' => (
    is              => 'ro',
    isa             => 'Str',
    lazy            => 1,
    default         => sub { shift->cert_file },
    documentation   => 'yes, by default it is cert_file'
);

sub _temp_pem_file {
    my ($content, $type) = @_;
    my $fh = File::Temp->new(TEMPLATE => "mr-apns-".$type."-".time()."-$$-XXXXXXXX", TEMPDIR  => 1, EXLOCK   => 0);
    syswrite $fh, $content;
    close $fh;
    return $fh->filename;
}

has 'cert'  => (
    is              => 'ro',
    isa             => 'Str',
    documentation   => 'content of cert .pem file',
    trigger => sub {
        my $self = shift;
        $self->cert_file( _temp_pem_file($_[0], 'cert') );
    } 
);

has 'key'  => (
    is              => 'ro',
    isa             => 'Str',
    documentation   => 'content of key .pem file',
    trigger => sub {
        my $self = shift;
        $self->key_file( _temp_pem_file($_[0], 'key') );
    } 
);

has 'password'  => (
    is              => 'ro',
    isa             => 'Str|CodeRef',
    documentation   => 'key password'
);

has 'sandbox'  => (
    is              => 'ro',
    isa             => 'Bool',
    lazy            => 1,
    default         => sub { 0 },
    documentation   => 'gateway target'
);

has 'hostname' => (
    is              => 'ro',
    isa             => 'Str',
    lazy            => 1,
    default         => sub {
        my $self = shift;
        return sprintf('gateway.%spush.apple.com', $self->sandbox ? 'sandbox.' : '')
    },    
);

has 'port' => (
    is              => 'ro',
    isa             => 'Int',
    lazy            => 1,
    default         => sub { 2195 },    
);

has ['write_timeout', 'last_read_timeout'] => (
    is              => 'rw',
    isa             => 'Num',
    lazy            => 1,
    default         => sub { 0.1 }
);

has '_ioselect'  => (
    is              => 'rw',
    isa             => 'Maybe[IO::Select]',
    lazy            => 1,
    predicate       => '_has_ioselect',
    clearer         => '_clean_ioselect',
    default         => sub {
        my $self = shift;
        socket(my $sock, Socket::PF_INET(), Socket::SOCK_STREAM(), 0) or die "can't create socket: $!";
        my $iaddr = Socket::inet_aton($self->hostname) or die sprintf "can't create iaddr from %s: %s", $self->hostname, $!;
        my $sock_addr = Socket::pack_sockaddr_in($self->port, $iaddr) or die "can't create sock_addr: $!";
        connect($sock, $sock_addr) or die "can't connect socket: $!";
        $sock->autoflush;
        return IO::Select->new($sock);
    },
    documentation   => 'simple select wrapper'
);

has '_ctx'  => (
    is              => 'rw',
    isa             => 'Int',
    lazy            => 1,
    predicate       => '_has_ctx',
    clearer         => '_clean_ctx',
    default         => sub {
        my $self = shift;
        my $ctx = Net::SSLeay::CTX_tlsv1_new() or _die_if_ssl_error("can't create SSL_CTX: $!");
        Net::SSLeay::CTX_set_options($ctx, Net::SSLeay::OP_ALL());
        _die_if_ssl_error("ctx options: $!");
        my $pw = $self->password;
        Net::SSLeay::CTX_set_default_passwd_cb($ctx, ref $pw ? $pw : sub { $pw });
        Net::SSLeay::CTX_use_certificate_file($ctx, $self->cert_file, Net::SSLeay::FILETYPE_PEM());
        _die_if_ssl_error("certificate: $!");
        Net::SSLeay::CTX_use_RSAPrivateKey_file($ctx, $self->cert_file, Net::SSLeay::FILETYPE_PEM());
        _die_if_ssl_error("private key: $!");        
        return $ctx;
    },
    documentation   => 'SSL_CTX object'
);

has '_ssl'  => (
    is              => 'rw',
    isa             => 'Int',
    lazy            => 1,
    predicate       => '_has_ssl',
    clearer         => '_clean_ssl',
    default         => sub {
        my $self = shift;
        my $ssl = Net::SSLeay::new($self->_ctx);
        Net::SSLeay::set_fd($ssl, fileno [$self->_ioselect->handles]->[0]);
        Net::SSLeay::connect($ssl) or _die_if_ssl_error("failed ssl connect: $!");
        return $ssl;
    },
    documentation   => 'SSL_CTX object'
);

has 'connect'  => (
    is              => 'rw',
    isa             => 'Bool',
    lazy            => 1,
    clearer         => '_clean_connect',
    predicate       => '_has_connect',
    default         => sub {
        my $self = shift;
        # start chain action
        $self->_ssl;
        return 1;
    },
    documentation   => 'connect state'
);

sub disconnect {
    my $self = shift;
    return unless $self->_has_connect;
    eval {
        my @sockets = ();
        if ($self->_has_ioselect) {
            @sockets = $self->_ioselect->handles;
            $self->_ioselect->remove(@sockets) if @sockets;
            for (@sockets) {
                die "can't shutdown socket: $!" unless defined CORE::shutdown($_, 1)
            };
        }
        
        if ($self->_has_ssl) {
            Net::SSLeay::free($self->_ssl);
            _die_if_ssl_error("failed ssl free: $!");
        }
    
        if ($self->_has_ctx) {
            Net::SSLeay::CTX_free($self->_ctx);
            _die_if_ssl_error("failed ctx free: $!");
        }
        
        close $_ or die "can't close socket: $!" for @sockets;
        
        $self->_clean_ctx; 
        $self->_clean_ssl;
        $self->_clean_ioselect;
        $self->_clean_connect;
    };
    return $@;
}

sub send {
    my $self = shift;
    my @messages = grep { $_->as_binary } @_;
    
    my $send_cnt = 0; my $error = '';

    my @apns_error = (); my $i = 0;
    for my $m (@messages) {
        my $status = $self->_send($m->as_binary, $i == @messages ? 1 : 0);
        if ($status->{error} eq 'timeout') {
            $m->error(-200);
        } elsif ($status->{error} eq 'fatal') {
            $error = $status->{error_str};
            last;
        } elsif ($status->{error} eq 'OK' and $status->{apns_error}) {
            push @apns_error, $status->{apns_error};
        }
        
        if ($status->{send}) {
            $send_cnt++;
            $m->error(-2);
        }
        
        $i++;
    }
    
    eval { $self->disconnect };
    $error = $@ if (not $error and $@);
    
    my %apns_error = map { %$_ } @apns_error;
    for (@messages) {
         if ( $apns_error{ $_->_identifier } ) {
             # ignore APNS_NO_ERRORS
             eval { $_->error($apns_error{ $_->_identifier }) };
             if ($@) {
                 $_->error(-255);
             };
         }
    }
    
    return ($send_cnt, $error);
}

sub _send {
    my $self = shift;
    my $payload = shift;
    my $last = shift;
    my $ret = {};
    eval { $self->connect };
    if ($@) {
        return {error => 'fatal', error_str => $@, send => 0};
    }
    my ($ready_socket) = $self->_ioselect->can_write( $self->write_timeout );
    unless ($ready_socket) {
        return {error => 'timeout', error_str => "socket timeout on write (0.1)", send => 0};
    }
    eval {
        Net::SSLeay::ssl_write_all($self->_ssl, $payload) or _die_if_ssl_error("ssl_write_all error: $!");
    };
    if ($@) {
        return {error => 'fatal', error_str => $@, status => 0};
    }
    ($ready_socket) = $self->_ioselect->can_read($last ? $self->last_read_timeout : 0);
    unless ($ready_socket) {
        return {error => 'OK', send => 1};
    }
    my $data = eval {
        Net::SSLeay::ssl_read_all($self->_ssl) or _die_if_ssl_error("ssl_read_all error: $!");
    };
    if ($@) {
        return {error => 'fatal', error_str => $@, send => 1};
    }
    unless ($data) {
        # apns closed connection (ignore error for payload)
        $self->disconnect;
        return {error => 'OK', send => 1};
    };
    my @apns_err = unpack '(CCL)*', $data;
    while ( my @e = splice(@apns_err, 0 , 3) ) {
        $ret->{ $e[2] } = $e[1];
    }
    return {error => 'OK', send => 1, apns_error => $ret};
}

sub _die_if_ssl_error {
    my $err = Net::SSLeay::print_errs("SSL error: $_[0]");
    Carp::croak $err if $err;
}

sub BUILD {
    my $self = shift;
    unless ($self->has_cert_file) {
        warn "cert_file is a necessary attribute";
        return;
    }
    Net::SSLeay::load_error_strings();
    Net::SSLeay::SSLeay_add_ssl_algorithms();
    Net::SSLeay::randomize();
    return $self;  
}

sub DEMOLISH {
    my $self = shift;
    $self->disconnect;
}

__PACKAGE__->meta->make_immutable;
no Mouse;
1;
__END__
