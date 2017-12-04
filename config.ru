# encoding: UTF-8
require 'rack/cache'
require './backdrifting'

# Make Passenger play nice with Apache
# Massively reduces page-load times in some environments
if defined?(PhusionPassenger)
	PhusionPassenger.advertised_concurrency_level = 0
end

use Rack::Cache,
	:verbose     => true,
	:metastore   => 'file:/var/cache/rack/meta',
	:entitystore => 'file:/var/cache/rack/body'

run Sinatra::Application
