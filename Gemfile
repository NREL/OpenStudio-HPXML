source 'http://rubygems.org'

ruby '~> 2.5.0'

# Local gems are useful when developing and integrating the various dependencies.
# To favor the use of local gems, set the following environment variable:
#   Mac: export FAVOR_LOCAL_GEMS=1
#   Windows: set FAVOR_LOCAL_GEMS=1
# Note that if allow_local is true, but the gem is not found locally, then it will
# checkout the latest version (develop) from github.
allow_local = ENV['FAVOR_LOCAL_GEMS']

gem 'urbanopt-scenario', github: 'URBANopt/urbanopt-scenario-gem', ref: '584b469'
gem 'urbanopt-geojson', '0.3.1'
gem 'openstudio-load-flexibility-measures', '0.1.3'
gem 'urbanopt-reopt', '0.3.0'
