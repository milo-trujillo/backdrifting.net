# encoding: UTF-8
require 'rack/cache'
require './backdrifting'

use Rack::Cache,
	:verbose     => true,
	:metastore   => 'file:/var/cache/rack/meta',
	:entitystore => 'file:/var/cache/rack/body'

run Sinatra::Application
