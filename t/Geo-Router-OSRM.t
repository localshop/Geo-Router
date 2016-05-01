


## NB running in taint mode doesn't work??? why ?? #!/usr/bin/perl -Tw

## NB - to see verbose output execute the following line from the install root directory
##      PERL_DL_NONLAZY=1 /usr/local/bin/perl "-MExtUtils::Command::MM" "-e" "test_harness(1, 'blib/lib', 'blib/arch')" t/*.t


use strict;
use warnings;
use Data::Dumper;
use Test::More;# 'no_plan'; # tests => 8;
use Module::Load::Conditional qw[can_load check_install requires];
    
BEGIN { use_ok('Geo::Router::OSRM')}
    
# is( $OSRM::VERSION, "v0.0.2");

#my $osrm = OSRM->new( { source=>'localhost', instructions => 'true' } );


SKIP: {
  skip('IO::Socket::PortState not installed unable to check for local OSRM service running so skipping local tests', 6 )
    unless check_install( module => 'IO::Socket::PortState' ); 

  use IO::Socket::PortState qw(check_ports);

  my $local_port_check = check_ports('127.0.0.1',5000,{ tcp=>{5000=>{}} });
#  print "foo = $foo\n";
#  print Dumper $foo;
#  ny $local_open = 
  skip('local service not running',6) unless $local_port_check->{tcp}{5000}{open};
  

   
  my $osrm = Geo::Router::OSRM->new( { source=>'localhost', instructions => 'true' } );


    ok( defined $osrm, 'new() returned something');
    ok( $osrm->isa('Geo::Router::OSRM'), 'and is the right class');

  my $route = $osrm->viaroute( [  [-27.919012,153.386215],[-27.936121,153.360809], [-28.033663, 153.434582]   ] );

    ok( defined $route, 'viaroute returned something');
    ok( $route->isa('Geo::Router::OSRM::Route'), 'and is the right class');
    ok( $route->formatted_instructions(), 'formatted_instructions()' );
    print Dumper $route->formatted_instructions();
    ok( $route->total_distance(),         'total_distance()' );
    
  my $loc = $osrm->locate( -27.919012,153.386215 );
  print "locate() result: " . Dumper $loc;

  my $nearest = $osrm->nearest( -27.919012,153.386215 );
  print "nearest() result: " . Dumper $nearest;
}


SKIP: {
    skip('OSRM Distance Matrix implementation not stable as of coding this so skipping',2);
  my $osrm = Geo::Router::OSRM->new( { source=>'osrm2', instructions => 'true' } );
  ok(defined $osrm, 'OSRM for matrix defined');
  my $matrix = $osrm->table( [  [-27.919012,153.386215],[-27.936121,153.360809], [-28.033663, 153.434582]   ] );
  ok( defined $matrix, 'matrix returned is defined');
  print Dumper $matrix;
}
  
done_testing;


