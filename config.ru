# encoding: UTF-8
require 'rack/cache'
require './backdrifting'

set :env,  :production

use Rack::Cache,
	:verbose     => true,
	:metastore   => 'file:/var/cache/rack/meta',
	:entitystore => 'file:/var/cache/rack/body'
	#:metastore   => 'file:tmp/meta',
	#:entitystore => 'file:tmp/body'

run Sinatra::Application
