source 'http://rubygems.org'

ruby '~> 2.5.0'

# Local gems are useful when developing and integrating the various dependencies.
# To favor the use of local gems, set the following environment variable:
#   Mac: export FAVOR_LOCAL_GEMS=1
#   Windows: set FAVOR_LOCAL_GEMS=1
# Note that if allow_local is true, but the gem is not found locally, then it will
# checkout the latest version (develop) from github.
allow_local = ENV['FAVOR_LOCAL_GEMS']

if allow_local && File.exist?('../openstudio-model-articulation-gem')
  gem 'openstudio-model-articulation', path: '../openstudio-model-articulation-gem'
elsif allow_local
  gem 'openstudio-model-articulation', github: 'NREL/openstudio-model-articulation-gem', branch: 'develop'
else
  gem 'openstudio-model-articulation', '~> 0.2.0'
end

gem 'urbanopt-scenario', github: 'URBANopt/urbanopt-scenario-gem', branch: 'develop'

if allow_local && File.exist?('../urbanopt-reporting-gem')
 gem 'urbanopt-reporting', path: '../urbanopt-reporting-gem'
elsif allow_local
 gem 'urbanopt-reporting', github: 'URBANopt/urbanopt-reporting-gem', branch: 'develop'
else
 gem 'urbanopt-reporting', '~> 0.2.0'
end

gem 'urbanopt-geojson', github: 'URBANopt/urbanopt-geojson-gem', branch: 'develop'

gem 'openstudio-load-flexibility-measures', github: 'NREL/openstudio-load-flexibility-measures-gem', branch: 'master'

gem 'urbanopt-reopt', '~>0.4.0'
