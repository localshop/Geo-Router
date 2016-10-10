package Geo::Router::OSRM;

use warnings;
use strict;
use Carp;
use LWP;
use JSON;
use Data::Dumper;
use Geo::Router::OSRM::Route;
use Geo::Google::PolylineEncoder;  ## NB - consider removing this functionality

use version; our $VERSION = version->declare("v0.04");
#our $VERSION = '0.02';
#$VERSION = eval $VERSION;


=head1 NAME

OSRM - Access Open Street Map Routing REST Web Service API

Can use either public OSM Service or other service.

More details about what the API service provides can do can be found at L<API website|https://github.com/Project-OSRM/osrm-backend/wiki/Server-api>

NB: This is not an official part of the OSM project and is provided by Peter in the hope that it will be useful to someone. It is fragile and
ugly and should not be depended on without significant testing for your use case.

=head1 VERSION

Version 0.04

=cut



=head1 ABSTRACT

    use Geo::Router::OSRM;

    my $osrm = Geo::Router::OSRM->new( );

    ## or 

    my $osrm = Geo::Router::OSRM->new( { url_base => 'http://otherdomain.com:5000', source=> 'custom' }  );


    my $waypoints = [  [-27.919012,153.386215],[-27.936121,153.360809], [-28.033663, 153.434582]   ];

    if ( my $route = $osrm->viaroute( $waypoints )  )
    {
      print $route->geometry_encoded();   ## see Geo::Router::OSRM::Route for docs
    }


=cut


our %SOURCES = (
    localhost      => 'http://localhost:5000',
    osrm           => 'http://router.project-osrm.org:5000',
    osrm_https     => 'https://router.project-osrm.org',
    custom         => '',
);

=head1 DESCRIPTION

This module excpsulates http requsts to Open Source Routing Machine services, providing a routes between waypoints using Open Street Data.

The OSRM providers are in principle happy to be queried from external users. They don't give any guarantees though and expect everyone to adhere to the following rules:

Excessive use (e.g. distance tables) is not allowed.
Clearly display appropriate data license attribution (ODbL) and the source of your routes (OSRM).
Valid User-Agent identifying application. Faking another app's User-Agent WILL get you blocked.
If known, a valid HTTP Referer. See Wikipedia for an explanation.

https://github.com/Project-OSRM/osrm-backend/wiki/API%20Usage%20Policy

We expect all external users to implement the API as efficiently as possible. The following is a must:
the coordinate hinting mechanism needs to be implemented.
The route geometry is compressed by an implementation of Googles Polyline Algorithm Format with a precision of six digits.
See here for a proper JavaScript implementation.
...
Write a mail to info@project-osrm.org to let us know that you are using our service.

=cut




#####################################

=head1 METHODS

=head2 new()

    my $osrm = Geo::Router::OSRM->new(); ## defaults to osrm server
    or
    my $osrm = Geo::Router::OSRM->new( { url_base => 'http://otherdomain.com:5000', source=> 'custom' }  );
    or
    my $osrm = Geo::Router::OSRM->new( { source=>'localhost'  });  ## Create an OSRM Query Agent


=head3 source

      specifies the id of the server that we will send requests to.
      Valid source values: localhost, osrm, osrm_https, sgd

=cut

sub new
{

    my $class = shift;
    my (  $ahr ) = @_;
    #return undef unless defined $ahr->{user_id};

    my $self = bless

    {
        ua => LWP::UserAgent->new(),
        source   => $ahr->{source}   || '',
        url_base => $ahr->{url_base} || '',
        api_version => $ahr->{api_version} || 4,
        error    => '',
        DEBUG    => '',
        json_result => '',
        via_params => {
            instructions => $ahr->{instructions} || 'true', # true || false
            alt          => 'false', ## if set to true then viaroute queries include alternative routes
        },
        routes => [],
       # request_options = {
       #     &z={0,...,18}
       #     &output={json, gpx}
       #     &jsonp=_function_
       #     &instructions={true, false}
       #     &alt={true, false}


    }, $class;


    if ( (defined $ahr->{url_base} and $ahr->{url_base} =~ /^http/m) and  ( $self->{source} eq 'custom' || not defined $SOURCES{ $self->{source} } ) )
    {
      $self->{source} = 'custom';
      $self->{url_base} = $ahr->{url_base};

    }


    return $self; ## get here if all values passed in as params ... could possibly include a check to sensure run_id is correct ... possibly option to create record
}

#####################################

=head2 locate()

    Sends a query to the OSRM service to obtain the nearest node point

    my ( $nearest_lat, $nearest_lng ) = $osrm->locate( [lat,lng] );

=cut

sub locate
{
    my ( $self, $lat, $lng ) = @_;
    if ( $self->{api_version} eq '4')
    {
      $self->{json_result} = $self->_request( qq{$self->{url_base}/locate?loc=$lat,$lng} );
      } 
      else 
      {
        die("API V5 Not yet implemented");
      }
    return $self->{json_result};
    die("Not yet implemetned");
}




=head2 nearest()

    Sends a query to the OSRM service to obtain the nearest point on a street segment

    my nearest = $osrm->nearest( [lat,lng] );

nearest result example as follows:
    {
        "status": 0,
        "mapped_coordinate": [
            52.42259,
            13.33383
        ],
        "name": "Mariannenstraße"
    }


=cut

sub nearest
{
    my ( $self, $lat, $lng ) = @_;
    # http://server:5000/nearest?loc=lat,lon

    $self->{json_result} = $self->_request( qq{$self->{url_base}/nearest?loc=$lat,$lng} );
    return $self->{json_result};
    die("Not yet implemetned");
}

=head2 viaroute()

Sends a query to the OSRM service.
Pass in a list of lat/lng pairs and returns an OSRM::Route object or undef if fail.
Returns  L<OSRM::Route>

    my $nearest = $osrm->viaroute( [ [lat,lng], ... ] )





=cut

sub viaroute
{
    my ( $self, $wp_array) = @_;
    $self->{source} = 'osrm' unless $self->{source};
    $self->{url_base} = $SOURCES{ $self->{source} } unless $self->{url_base};
    ## validate input
    return $self->error("Error: via route  requires an array of waypoints") unless ( ref $wp_array eq 'ARRAY');
    my $wpoints = '';
    foreach my $p  ( @$wp_array )
    {
        return $self->error("Error: Waypoints must contain array of [lat,lng] points") unless ( ref $p eq 'ARRAY' && @$p==2);
        $wpoints .=  ($wpoints eq '') ? '?' : '&';
        $wpoints .= qq{loc=$p->[0],$p->[1]};
    }
    ## API Docs say 25 point limit - should warn if try to exceed?
    #
    #my $content =
    #print qq{$self->{url_base}/viaroute$wpoints};
    #exit;
    $self->{json_result} = $self->_request( qq{$self->{url_base}/viaroute$wpoints&instructions=$self->{via_params}{instructions}&alt=$self->{via_params}{alt}} );

    #/table?loc=29.94,-90.11&loc=30.44,-91.18&loc=30.45,-91.22&loc=30.42,-91.15
    #return $self->error('')
    #print Dumper $json_result;
    #exit;
    ## process result - create route object/s and populate
    return $self->process_via_json( $self->{json_result})         if ( defined $self->{json_result}{status} && $self->{json_result}{status} == 0 );
    return $self->error($self->{json_result}{status_message}) if ( defined $self->{json_result}{status_message}  );
    return $self->error("Error: Unable to process $!");
}

sub process_via_json
{
    my ( $self ) = @_;

    $self->{routes}[0] = Geo::Router::OSRM::Route->new({
       # 'start_desc' => $self->{json_result}
       # 'finish_desc' =>  $self->{json_result}
        'route_summary'            => $self->{json_result}{route_summary},
        'route_geometry'           => $self->{json_result}{route_geometry},
        'route_instructions'       => $self->{json_result}{route_instructions},
        'total_distance'           => $self->{json_result}{route_summary}{total_distance},
        'total_duration'           => $self->{json_result}{route_summary}{total_time},
        'via_points'               => $self->{json_result}{via_points},
    });


    #foreach
    #print Dumper $self->{json_result};
    return $self->{routes}[0];

}



=head2 table()

Sends a query to the OSRM service for computation of distance tables.
Given a list of locations a matrix is returned containing the travel time for all combinations of trips.

  NB: Not implemented

  my $matrix = $osrm->table( [ [lat,lng],[lat,lng], ...  ] );

=cut

sub table
{
  my ( $self, $wp_array) = @_;
  $self->{source} = 'osrm' unless $self->{source};
  $self->{url_base} = $SOURCES{ $self->{source} } unless $self->{url_base};
  ## validate input
  return $self->error("Error: via route  requires an array of waypoints") unless ( ref $wp_array eq 'ARRAY');
  my $wpoints = '';
  foreach my $p  ( @$wp_array )
  {
    return $self->error("Error: Waypoints must contain array of [lat,lng] points") unless ( ref $p eq 'ARRAY' && @$p==2);
    $wpoints .=  ($wpoints eq '') ? '?' : '&';
    $wpoints .= qq{loc=$p->[0],$p->[1]};
  }
  ## API Docs say 25 point limit - should warn if try to exceed?

#my $content =
#print qq{$self->{url_base}/viaroute$wpoints};
#exit;
  $self->{json_result} = $self->_request( qq{$self->{url_base}/table$wpoints&z=12} );
#$self->{json_result} = $self->_request( qq{$self->{url_base}/table?loc=29.94,-90.11&loc=30.44,-91.18&loc=30.45,-91.22&loc=30.42,-91.15&z=12});
  return $self->{json_result};
#/table?loc=29.94,-90.11&loc=30.44,-91.18&loc=30.45,-91.22&loc=30.42,-91.15
#return $self->error('')
#print Dumper $self->{json_result};
#exit;
## process result - create route object/s and populate
#return $self->process_json( $self->{json_result})         if ( defined $self->{json_result}{status} && $self->{json_result}{status} == 0 );
#return $self->error($self->{json_result}{status_message}) if ( defined $self->{json_result}{status_message}  );
#return $self->error("Error: Unable to process $!");
}

##############
#
##sub query_osrm
#{
#  my ( $self, $start, $dest ) = @_;
#
#  my $ua = LWP::UserAgent->new();
#  my $OSRM_BASE_URI = 'http://localhost:5000/viaroute';
# # $OSRM_BASE_URI = 'http://osrm.pscott.com.au:5000/viaroute';
#  ## eg http://localhost:5000/viaroute?loc=-27.919012,153.386215&loc=-27.936121,153.360809
#  # http://osrm.pscott.com.au:5000/viaroute?loc=-27.919012,153.386215&loc=-27.936121,153.360809
#  if ( $start->{lat} == $dest->{lat} and $start->{lng} == $dest->{lng} )
#  {
#    warn('trying to route to origin');
##    return {
#        route    => '',
#        distance => 0,
#        duration => 0,
#      };
#  }#


#  my $uri = qq{$OSRM_BASE_URI?loc=$start->{lat},$start->{lng}&loc=$dest->{lat},$dest->{lng}\n};
#  my $res = $ua->get( $uri );
#  #print "Checking $uri\n" if $DEBUG;
#  return $self->process_osrm_returned_result(  from_json(  $res->content() )  ) || die( $! );

  #
#}

##############




sub _request {
    my ($self, $uri) = @_;

    return unless $uri;

    my $res = $self->{response} = $self->{ua}->get($uri);
    return $self->error('Invalid http response') unless $res->is_success;

    # Change the content type of the response (if necessary) so
    # HTTP::Message will decode the character encoding.
   # $res->content_type('text/plain')
   #     unless $res->content_type =~ /^text/;

    my $content = $res->decoded_content;
    #print "$content";
    return unless $content;

    my $data = eval { from_json($content) };
    return unless $data;

    return $data;
#    my @results = 'ARRAY' eq ref $data ? @$data : ($data);
#    return wantarray ? @results : $results[0];
}


sub error
{
    my ( $self, $msg) = @_;
    return $self->{error} if ( not defined $msg );
    $self->{error} .= "$msg";
    warn($msg) if $self->{DEBUG};
    return undef;
}

1;

__END__

=head1 TODO

=over

=item *Implement locate() service - Location of a nearest node of the road network to a given coordinate (locate).

=item *Implement nearest() service

=item *include optional alternative results from viaroute - currently ignored

=back

=head1 REQUESTS AND BUGS

Please report any bugs or feature requests to Peter Scott, <pscott at shogundriver.com>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc OSRM

You can also look for information at:

=over

=item * Project OSRM Page

L<http://project-osrm.org>

=item * OSRM Web Interface

L<http://http://map.project-osrm.org>

=back

=head1 SEE ALSO

L<http://wiki.openstreetmap.org/wiki/Nominatim>

L<http://open.mapquestapi.com/nominatim/>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2016 Peter Scott <peter at pscott.com.au>, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=head1 AUTHOR

Peter Scott, <peter at pscott.com.au>

=cut
