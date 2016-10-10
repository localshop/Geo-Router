
Geo-Router-OSRM version 0.0.4
=============================

This CPAN style Perl Module provides access to Open Street Map Routing REST Web Service API

Can use either public OSM Service or other service.

More details about what the API service provides can do can be found at API website [https://github.com/Project-OSRM/osrm-backend/wiki/Server-api]


INSTALLATION
------------

To install this module type the following:

   perl Makefile.PL
   make
   make test
   make install

DEPENDENCIES
------------

This module requires these other modules and libraries:

  LWP
  JSON
  Geo::Google::PolylineEncoder

COPYRIGHT AND LICENCE


Copyright (C) 2014-2016 by Peter Scott

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.