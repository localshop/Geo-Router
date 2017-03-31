
Geo-Router-OSRM version 0.21
=============================


*WARNING - THIS MODULE IS BEING REWRITTEN TO WORK FOR BOTH THE OLD V4 AND THE NEWER V5 - not really usable at the moment*

Am aiming to release a working version before March 2017

This CPAN style Perl Module provides access to Open Street Map Routing REST Web Service API

Can use either public OSM Service or other service.

More details about what the API service provides can do can be found at API website [https://github.com/Project-OSRM/osrm-backend/wiki/Server-api]


INSTALLATION
------------

To install this module type the following:


    perl Makefile.PL
    make
    make test
      or
    make test TEST_VERBOSE=true
    make install

TESTING AGAINST A LIVE SERVICE
------------------------------

When running make test if the ````OSRM_URL_BASE```` environment variable is set then tests will be performed against this endpoint ( currently with hard-coded australian locations )
eg. 

     export OSRM_URL_BASE=http://localhost:5000


DEPENDENCIES
------------

This module requires these other modules and libraries:

  * LWP
  * JSON
  * Geo::Google::PolylineEncoder
  * IO::Socket::PortState ( if running tests against live service )

OSRM API VERSIONS
-----------------
"As of 2016-04-08, the master branch (the default if you clone from Github) will give you the 5.x API. The demo server will serve both APIs until approximately mid-2016, after which the 4.x API will be shut down." [https://github.com/Project-OSRM/osrm-backend/wiki/Server-API---v4,-old]
- if attempt to access the old API version structured URLs against the OSRM servers you will receive a response such as 'The OSRM Demo server has moved to API Version 5. Documentation for the new version can be found at https://github.com/Project-OSRM/osrm-backend/blob/master/docs/http.md' and even if you specifically request this version, this module will attempt the new version if this response is received.


### OSRM V5 API

```
http://{server}/{service}/{version}/{profile}/{coordinates}[.{format}]?option=value&option=value
```

- `server`: location of the server. Example: `127.0.0.1:5000` (default)
- `service`: Name of the service to be used. Support are the following services:
  
    | Service     |           Description                                     |
    |-------------|-----------------------------------------------------------|
    | [`route`](#service-route)     | fastest path between given coordinates                   |
    | [`nearest`](#service-nearest)   | returns the nearest street segment for a given coordinate |
    | [`table`](#service-table)     | computes distance tables for given coordinates            |
    | [`match`](#service-match)     | matches given coordinates to the road network             |
    | [`trip`](#service-trip)      | Compute the fastest round trip between given coordinates |
    | [`tile`](#service-tile)      | Return vector tiles containing debugging info             |
  
- `version`: Version of the protocol implemented by the service.
- `profile`: Mode of transportation, is determined statically by the Lua profile that is used to prepare the data using `osrm-extract`.
- `coordinates`: String of format `{longitude},{latitude};{longitude},{latitude}[;{longitude},{latitude} ...]` or `polyline({polyline})`.
- `format`: Only `json` is supported at the moment. This parameter is optional and defaults to `json`.

### Perl Libray Examples of accessing these services


FUTURE PLANS
------------
- ideally would like to bind to underlaying C++ libs using https://metacpan.org/pod/ExtUtils::XSpp



COPYRIGHT AND LICENCE


Copyright (C) 2014-2017 by Peter Scott

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.