package Geo::Router::OSRM;

use warnings;
use strict;
use Carp;
use LWP;
use JSON;
use Data::Dumper;
use Geo::Router::OSRM::Route;
use Geo::Google::PolylineEncoder;  ## NB - consider removing this functionality
use Scalar::Util qw(looks_like_number);

use version; our $VERSION = version->declare("0.21");



=head1 NAME

OSRM - Access Open Street Map Routing REST Web Service API

Can use either public OSM Service or other service.

More details about what the API service provides can do can be found at L<API website|https://github.com/Project-OSRM/osrm-backend/wiki/Server-api>

NB: This is not an official part of the OSM project and is provided by Peter in the hope that it will be useful to someone. It is fragile and
ugly and should not be depended on without significant testing for your use case.

=head1 VERSION

Version 0.21

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

=head2 CHANGES

Dec,2016 - Refactored new to accept hash instead of hashref 
         - refactoring to work with v1 OSRM 5.x installations


#####################################

=head1 METHODS

=head2 new()

    my $osrm = Geo::Router::OSRM->new( ); ## defaults to osrm server
    or
    my $osrm = Geo::Router::OSRM->new(  url_base => 'http://otherdomain.com:5000', source=> 'custom', api_version=>4  );
    or
    my $osrm = Geo::Router::OSRM->new(  source=>'localhost'  );  ## Create an OSRM Query Agent


=head3 source

      specifies the id of the server that we will send requests to.
      Valid source values: localhost, osrm, osrm_https, sgd

=cut

sub new
{

    my ($class, $ahr)   = @_;
    
    #return undef unless defined $ahr->{user_id};

    my $self = bless
    {
        ua => LWP::UserAgent->new(),
        source   => $ahr->{source}   || '',
        url_base => $ahr->{url_base} || '',
        api_version => $ahr->{api_version} || 5, ## still some cruff from 4 but may not be handled well- default 5
        profile => $ahr->{profile} || 'car', ## new in v 5
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
    if ( $self->{api_version} eq '4' )
    {
      $self->{json_result} = $self->_request( qq{$self->{url_base}/locate?loc=$lat,$lng} );
    }
    elsif ( $self->{api_version} eq '5' )
    {
      $self->{json_result} = $self->_request( qq{$self->{url_base}/locate?loc=$lat,$lng} );
      #die("API V5 Not yet implemented");
    } 
    else 
    {
      return $self->_error("unexpected version $self->{api_version}");
    }
    return $self->{json_result};
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
    my ( $self,  $lng, $lat ) = @_;
    # http://server:5000/nearest?loc=lat,lon
    if ( $self->{api_version} eq '4')
    {
      $self->{json_result} = $self->_request( qq{$self->{url_base}/nearest?loc=$lat,$lng} );
    } 
    elsif ( $self->{api_version} eq '5' ) 
    {
      print qq{$self->{url_base}/nearest/v1/driving/$lng,$lat\n};
      $self->{json_result} = $self->_request( qq{$self->{url_base}/nearest/v1/driving/$lng,$lat} );
    }

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
    return $self->_error("Error: via route  requires an array of waypoints") unless ( ref $wp_array eq 'ARRAY');
    my $wpoints = '';
    foreach my $p  ( @$wp_array )
    {
        return $self->_error("Error: Waypoints must contain array of [lat,lng] points") unless ( ref $p eq 'ARRAY' && @$p==2);
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
    #return $self->_error('')
    #print Dumper $json_result;
    #exit;
    ## process result - create route object/s and populate
    return $self->process_via_json( $self->{json_result})         if ( defined $self->{json_result}{status} && $self->{json_result}{status} == 0 );
    return $self->_error($self->{json_result}{status_message}) if ( defined $self->{json_result}{status_message}  );
    return $self->_error("Error: Unable to process $!");
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
  return $self->_error("Error: via route  requires an array of waypoints") unless ( ref $wp_array eq 'ARRAY');
  my $wpoints = '';
  foreach my $p  ( @$wp_array )
  {
    return $self->_error("Error: Waypoints must contain array of [lat,lng] points") unless ( ref $p eq 'ARRAY' && @$p==2);
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
#return $self->_error('')
#print Dumper $self->{json_result};
#exit;
## process result - create route object/s and populate
#return $self->process_json( $self->{json_result})         if ( defined $self->{json_result}{status} && $self->{json_result}{status} == 0 );
#return $self->_error($self->{json_result}{status_message}) if ( defined $self->{json_result}{status_message}  );
#return $self->_error("Error: Unable to process $!");
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
    return $self->_error('Invalid http response') unless $res->is_success;

    # Change the content type of the response (if necessary) so
    # HTTP::Message will decode the character encoding.
   # $res->content_type('text/plain')
   #     unless $res->content_type =~ /^text/;

    my $content = $res->decoded_content;
    
    return unless $content;

    my $data = eval { from_json($content) }; ## security warning - evals are bad - are you sure about content?
    return unless $data;

    return $data;
#    my @results = 'ARRAY' eq ref $data ? @$data : ($data);
#    return wantarray ? @results : $results[0];
}


sub _error
{
    my ( $self, $msg) = @_;
    return $self->{error} if ( not defined $msg );
    $self->{error} .= "$msg";
    warn($msg) if $self->{DEBUG};
    return undef;
}


=head2 get()

  queries the OSRM service (OSRM 5.x installations with endpoint as defined in self ) using the following named parameters:

service: route|nearest|table|match|trip|tile
version: (always 1) - not required  
profile: one of- bike, car, foot as per server profile
coordinates: one of - string of google encoded polyline coordinates  with precision 5 , 
                      string of format {longitude},{latitude};{longitude},{latitude}
                      or an array of arrays of coordinate values (which can be either an array of lng,lat numbers 
                            or possible in the future a form of Geo::Location object).


  called in a scalar context returns the raw json string
  called in a array context returns result as a perl hash structure

  e.g.
  my $version = $osrm->get( service => 'route', version => 1, profile => 'car', coordinates=> [ [$lng1,$lat1], [128,-27, 129,-28] ] );
  my $
  
  my $route = $osrm->get( service=> 'route', profile=> 'car', coordinates=> [ [ $self->{lng}, $self->{lat} ], @stripped_locs ] )

=cut 

sub get
{
  my ( $self, %params ) = @_;
  return $self->_err('service param must be one of: route nearest table match trip tile')  unless $params{'service'} =~ m/route|nearest|table|match|trip|tile/img;
  return $self->_get_route(%params) if ( $params{'service'} =~ /route/im );
}



## checks if a value is numeric 
#sub _numeric { my ($self,$obj) = @_; no warnings "numeric"; return length($obj & ""); } 
# gave up on this approach as caused some issues - consider looking at 
#    use Scalar::Util qw(looks_like_number);
#    as per https://perlmaven.com/automatic-value-conversion-or-casting-in-perl
#print numeric("w") . "\n"; #=>0, print numeric("x") . "\n"; #=>0, print numeric("1") . "\n"; #=>0, print numeric(3) . "\n"; #=>1, print numeric("w") . "\n"; #=>1
# as per http://stackoverflow.com/questions/12647/how-do-i-tell-if-a-variable-has-a-numeric-value-in-perl
=pod _get_route()

GET /route/v1/{profile}/{coordinates}?alternatives={true|false}&steps={true|false}&geometries={polyline|polyline6|geojson}&overview={full|simplified|false}&annotations={true|false}

example URL:  
  # Query on Berlin with three coordinates and no overview geometry returned:
  curl 'http://router.project-osrm.org/route/v1/driving/13.388860,52.517037;13.397634,52.529407;13.428555,52.523219?overview=false'

=cut 

sub _get_route
{
  my ( $self, %params ) = @_;
  #print Dumper \%params;
  return $self->_error('unable to get route without list of waypoints') unless ref( $params{coordinates} ) eq 'ARRAY';
  ## if trying to route to self, duplicate the waypoint and warn so that doesn't break
  
  if (@{$params{coordinates}}==1)
  {
    $self->_error("Getting a route with a single point is a little pointless don't you think?");
    $params{coordinates} = [ $params{coordinates}[0],$params{coordinates}[0] ] ;
  }
  $params{annotations} = 'false' unless $params{annotations};
  $params{steps}       = 'true' unless $params{step};

  my $wp_strings = [];
  foreach my $point ( @{$params{coordinates}} )
  {
    return $self->_error('Waypoint not an array containing long and lat numeric values') unless ( looks_like_number($point->[0]) );
    push @$wp_strings, "$point->[0],$point->[1]";
   # print "$point->[0],$point->[1]\n";
  }
  my $uri =  qq{$self->{url_base}/route/v1/driving/} . join( ';', @$wp_strings) . "?annotations=$params{annotations}&steps=$params{steps}";
  #print "$uri\n\n";
  #print  qq{$self->{url_base}/route/v1/driving/} . join( ';',@$wp_strings) . "\n";
  $self->{json_result} = $self->_request( $uri );
  return $self->process_via_json_v5( $self->{json_result} );
}



sub process_via_json_v5
{
    my ( $self, $json ) = @_;

    $json = $self->{json_result} unless $json;

    return $self->_error('Unable to create route object from invalid JSON') unless ( defined $json and $json->{code} eq 'Ok');

    ## parse first route object in list of routes as described in https://github.com/Project-OSRM/osrm-backend/blob/master/docs/http.md#result-objects

    ## 
    my $start_point = $json->{routes}[0]{via_points}[0]{location};
    my $end_point   = $json->{routes}[0]{via_points}[ -1 ]{location}; ## NB -1 index refers to last element

    my $route_summary = {
      start_point => $start_point,
      end_point   => $end_point,
      total_distance =>  $json->{routes}[0]{distance},
      total_duration => $json->{routes}[0]{duration}
    };
    $self->{routes}[0] = Geo::Router::OSRM::Route->new({
       # 'start_desc' => $self->{json_result}
       # 'finish_desc' =>  $self->{json_result}

        'route_summary'            => $route_summary, #$json->{routes}[0]{route_summary},
        'route_geometry'           => $json->{routes}[0]{geometry},
        #'route_instructions'       => $self->{json_result}{route_instructions},
        'total_distance'           => $json->{routes}[0]{distance},
        'total_duration'           => $json->{routes}[0]{duration},
        'via_points'               => $json->{waypoints},
    }) || die('critical error - failed to create route');

    

    #foreach
    #print Dumper $self->{json_result};
    return $self->{routes}[0];

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

Copyright (C) 2014-2017 Peter Scott <peter at pscott.com.au>, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=head1 AUTHOR

Peter Scott, <peter at pscott.com.au>

=cut
