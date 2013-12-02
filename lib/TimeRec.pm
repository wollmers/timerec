package TimeRec;
use Mojo::Base 'Mojolicious';

our $VERSION = 0.008;
$VERSION = eval $VERSION;

has db => sub {
  my $self = shift;
  my $schema_class = $self->config->{db_schema} or die "Unknown DB Schema Class";
  eval "require $schema_class" or die "Could not load Schema Class ($schema_class)";

  my $db_connect = $self->config->{db_connect} or die "No DBI connection string provided";
  my @db_connect = ref $db_connect ? @$db_connect : ( $db_connect );

  my $schema = $schema_class->connect( @db_connect ) 
    or die "Could not connect to $schema_class using $db_connect[0]";

  return $schema;
};

has config_file => sub {
  my $self = shift;
  return $ENV{TIMEREC_CONFIG} if $ENV{TIMEREC_CONFIG}; 
  return "$ENV{MOJO_HOME}/timerec.conf" if $ENV{MOJO_HOME};
  return "$ENV{DOCUMENT_ROOT}/timerec.conf" if $ENV{DOCUMENT_ROOT};
  return "/var/www/timerec/timerec.conf";
};

sub startup {
  my $app = shift;
  
  $app->plugin( Config => { 
    file => $app->config_file,
  });
  
  $app->plugin('I18N');
  
  $app->secret( $app->config->{secret} );

  $app->helper( schema => sub { shift->app->db } );
  
  $app->helper( 'home_page' => sub{ '/' } );

  $app->helper( 'auth_fail' => sub {
    my $self = shift;
    my $message = shift || "Not Authorized";
    $self->flash( onload_message => $message );
    $self->redirect_to( $self->home_page );
    return 0;
  });
  
  $app->helper( 'get_user' => sub {
    my ($self, $name) = @_;
    unless ($name) {
      $name = $self->session->{username};
    }
    return undef unless $name;
    return $self->schema->resultset('User')->single({name => $name});
  });
  $app->helper( 'is_admin' => sub {
    my $self = shift;
    my $user = $self->get_user(@_);
    return undef unless $user;
    return $user->name eq 'admin';
  });

  my $routes = $app->routes;

  # Normal route to controller
  $routes->get('/')->to('front#index');
  $routes->get('/front/*name')->to('front#page');
  $routes->post('/save')->to('front#save');
  $routes->post( '/login' )->to('user#login');
  $routes->any( '/logout' )->to('user#logout');
  
  my $if_admin = $routes->under( sub {
    my $self = shift;

    return $self->auth_fail unless $self->is_admin;

    return 1;
  });

  $if_admin->any( '/admin/users' )->to('admin#users');
  $if_admin->any( '/admin/user/:name' )->to('admin#user');
  $if_admin->post( '/store/user' )->to('admin#store_user');

}

1;

__END__

=head1 NAME

TimeRec - A time recording application based on Mojolicious

=head1 SYNOPSIS

 $ timerec setup
 $ timerec daemon

=head1 DESCRIPTION

L<TimeRec> is a Perl web apllication.

=head1 INSTALLATION

L<TimeRec> uses well-tested and widely-used CPAN modules, so installation should be as simple as

    $ cpanm TimeRec

when using L<App::cpanminus>. Of course you can use your favorite CPAN client or install manually by cloning the L</"SOURCE REPOSITORY">.

=head1 SETUP

=head2 Environment

Although most of L<TimeRec> is controlled by a configuration file, a few properties must be set before that file can be read. These properties are controlled by the following environment variables.

=over 

=item C<TIMEREC_HOME>

This is the directory where L<TimeRec> expects additional files. These include the configuration file and log files. The default value is the current working directory (C<cwd>).

=item C<TIMEREC_CONFIG>

This is the full path to a configuration file. The default is a file named F<timerec.conf> in the C<TIMEREC_HOME> path, however this file need not actually exist, defaults may be used instead. This file need not be written by hand, it may be generated by the C<timerec config> command.

=back

=head2 The F<timerec> command line application

L<TimeRec> installs a command line application, C<timerec>. It inherits from the L<mojo> command, but it provides extra functions specifically for use with TimeRec.

=head3 config

 $ timerec config [options]

This command writes a configuration file in your C<TIMEREC_HOME> path. It uses the preset defaults for all values, except that it prompts for a secret. This can be any string, however stronger is better. You do not need to memorize it or remember it. This secret protects the cookies employed by TimeRec from being tampered with on the client side.

L<TimeRec> does not need to be configured, however it is recommended to do so to set your application's secret. 

The C<--force> option may be passed to overwrite any configuration file in the current working directory. The default is to die if such a configuration file is found.

=head3 setup

 $ timerec setup

This step is required. Run C<timerec setup> to setup a database. It will use the default DBI settings (SQLite) or whatever is setup in the C<GALILEO_CONFIG> configuration file.

=head1 RUNNING THE APPLICATION

 $ timerec daemon

After the database is has been setup, you can run C<timerec daemon> to start the server. 

You may also use L<morbo> (Mojolicious' development server) or L<hypnotoad> (Mojolicious' production server). You may even use any other server that Mojolicious supports, however for full functionality it must support websockets. When doing so you will need to know the full path to the C<timerec> application. A useful recipe might be

 $ hypnotoad `which timerec`

where you may replace C<hypnotoad> with your server of choice.

=head2 Logging

Logging in L<TimeRec> is the same as in L<Mojolicious|Mojolicious::Lite/Logging>. Messages will be printed to C<STDERR> unless a directory named F<log> exists in the C<TIMEREC_HOME> path, in which case messages will be logged to a file in that directory.

=head1 TECHNOLOGIES USED

=over

=item * 

L<Mojolicious|http://mojolicio.us> - a next generation web framework for the Perl programming language

=item * 

L<DBIx::Class|http://www.dbix-class.org/> - an extensible and flexible Object/Relational Mapper written in Perl

=item * 

L<Bootstrap|http://twitter.github.com/bootstrap> - the CSS/JS library from Twitter

=item * 

L<jQuery|http://jquery.com/> - jQuery


=back

=head1 SEE ALSO

=over

=item *

L<Contenticious> - File-based Markdown website application

=back

=head1 SOURCE REPOSITORY

L<http://github.com/wollmers/timerec>

=head1 AUTHOR

Helmut Wollmersdorfer, E<lt>helmut.wollmersdorfer@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Helmut Wollmersdorfer

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut



