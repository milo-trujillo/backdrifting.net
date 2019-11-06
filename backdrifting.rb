#!/usr/local/bin/ruby
# encoding: UTF-8
require 'sinatra'
require 'tilt/erb'
require 'kramdown'
require 'kramdown-syntax-coderay'
require 'rack/mobile-detect'
use Rack::MobileDetect

Private = File.dirname(__FILE__) + "/private"
PostsDir = Private + "/posts"
PreviewDir = Private + "/preview"
PreviewPassword = ""
PostSeparator = "\n<center><hr></center>\n"
SiteName = ""
SiteURL = ""
SiteDomains = ["example.com", "www.example.com"]
TwitterHandle = "@foo"
SocialMediaImageURL = "/images/qr.png"
Description = "Digital Haven"
FeedSize = 10 # How many posts to put in the RSS
AnalyticsEnabled = false
AnalyticsDatabaseURL = "redis://127.0.0.1:6379/"
AnalyticsPassword = ""

before '*' do
	if( request.url.start_with?("http://") )
		redirect to (request.url.sub("http", "https"))
	end
	if( env.key?("X_MOBILE_DEVICE") )
		@layout = :layout_mobile
	else
		@layout = :layout
	end
end

if AnalyticsEnabled
	require 'redis'
	require 'uri'
	redis = Redis.new(url: AnalyticsDatabaseURL, password: AnalyticsPassword)
	# Save some minimal analytics for every page hit
	after '*' do
		pass if( status == 404 )
		page = URI.parse(request.url).request_uri[1..-1]
		ref = request.referer
		redis.multi do
			# We don't care about counting the 'about' and 'contact' hits
			# Just engagement for each post
			if( page.start_with?("post/") )
				redis.hincrby("pagehits", page, 1)
			end
			# If there's a referrer that's not us, record it
			if( ref.nil? == false and not SiteDomains.include?(URI.parse(ref).host) )
				redis.hincrby("referrers", ref, 1)
			end
		end
	end
	# And add an access panel for that data
	get '/analytics/' + PreviewPassword do
		pagehits = redis.hgetall("pagehits")
		referrers = redis.hgetall("referrers")
		erb :analytics, :locals => {:pagehits => pagehits, :referrers => referrers}, :layout => @layout
	end
end

# Make all requests to non-existant pages give our 404 page
error Sinatra::NotFound do
	erb :notfound, :layout => @layout
end

# And do the same if one of our functions throws a 404
not_found do
	status 404
	erb :notfound, :layout => @layout
end

def getMarkdown(filename)
	begin
		f = File.open(Private + "/" + filename, "r")
		md = Kramdown::Document.new(f.read, {:syntax_highlighter=>:coderay, :syntax_highlighter_opts=>{:line_numbers=>nil}}).to_html
		f.close
		return md
	rescue
		return ""
	end
end

def getTitleFromPostHTML(html)
	return html.match(/>(.+)</)[1]
end

# To sort posts numerically we need to get their number
# This is everything up to the "_", converted to an int
def getPostNumber(filename)
	return filename[/^(.+)_/].to_i
end

# Renders the markdown for a post and generates appropriate 'sharing' buttons
# Also adds metadata tags so social media will make a cute preview
def renderPost(postfilename)
	postname = File.basename(postfilename, ".md")
	text = getMarkdown("posts/" + postfilename)
	title = getTitleFromPostHTML(text)
	if( text.length == 0 ) # No post, so don't add the share buttons
		return text
	end

	header = <<METADATA_END
<meta name="twitter:card" content="summary" />
<meta name="twitter:site" content="#{TwitterHandle}" />
<meta name="twitter:title" content="#{title}" />
<meta name="twitter:image" content="#{SiteURL + SocialMediaImageURL}" />
METADATA_END

	encodedURL = ERB::Util.url_encode(SiteURL + "/post/")
	share = <<SHARE_END
<ul class="share-buttons">
  <li><a href="https://twitter.com/intent/tweet?share=#{encodedURL}#{postname}" target="_blank" title="Tweet"><img src="/share/twitter.png" width=24px></a></li>
  <li><a href="http://www.reddit.com/submit?url=#{encodedURL}#{postname}&title=Backdrifting" target="_blank" title="Submit to Reddit"><img src="/share/reddit.png" width=24px></a></li>
  <li><a href="mailto:?subject=Backdrifting&body=#{encodedURL}#{postname}" target="_blank" title="Email"><img src="/share/email.png" width=24px></a></li>
  <li><a href="/post/#{postname}" target="_blank" title="Permalink"><img src="/share/pin.png" width=24px></a></li>
</ul>
SHARE_END

	text = header + text
	text += share
	return text
end

# Pre-load and render all posts
$posts = Hash.new()
posts = Dir.entries(PostsDir).select do |f| 
	File.file?(PostsDir + "/" + f) and f.end_with?(".md")
end
for post in posts
	$posts[post] = renderPost(post)
end




get '/' do
	text = ""
	posts = $posts.keys.sort { |x,y| getPostNumber(x) <=> getPostNumber(y) }
	for post in posts.reverse[0..4]
		text += ($posts[post] + PostSeparator)
	end
	erb :frontpage, :locals => { :text => text }, :layout => @layout
end

get '/mobiletest' do
	text = ""
	posts = $posts.keys.sort { |x,y| getPostNumber(x) <=> getPostNumber(y) }
	for post in posts.reverse[0..4]
		text += ($posts[post] + PostSeparator)
	end
	erb :frontpage, :locals => { :text => text }, :layout => :layout_mobile
end

get '/allPosts' do
	text = ""
	posts = $posts.keys.sort { |x,y| getPostNumber(x) <=> getPostNumber(y) }
	for post in posts.reverse
		text += ($posts[post] + PostSeparator)
	end
	erb :markdown, :locals => { :text => text }, :layout => @layout
end

get '/secretPreviews/' + PreviewPassword do
	text = ""
	posts = Dir.entries(PreviewDir).select do |f| 
		File.file?(PreviewDir + "/" + f) and f.end_with?(".md")
	end
	for post in posts.sort.reverse
		text += (getMarkdown("preview/" + post) + "\n<hr>\n")
	end
	erb :markdown, :locals => { :text => text }, :layout => @layout
end

get '/archive' do
	filenames = $posts.keys.sort { |x,y| getPostNumber(x) <=> getPostNumber(y) }
	posts = []
	for file in filenames.reverse
		firstLine = File.open("#{PostsDir}/#{file}", "r"){ |f| f.readline }
		articleName = firstLine.gsub("#", "")
		posts.push([File.basename(file, ".md"), articleName])
	end
	erb :archive, :locals => { :posts => posts }, :layout => @layout
end

get '/post/:name' do |name|
	if( name =~ /[^A-Za-z0-9_]/ )
		halt 404
	end
	postName = name + ".md"
	if( $posts.keys.include?(postName) )
		erb :markdown, :locals => { :text => $posts[postName] }, :layout => @layout
	else
		halt 404
	end
end

get '/rss' do
	content_type "text/xml"
	xml = <<END_XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
<channel>
<title>#{SiteName}</title>
<link>#{SiteURL}</link>
<description>#{Description}</description>
END_XML
	posts = Dir.entries(PostsDir).select do |f|
		File.file?(PostsDir + "/" + f) and f.end_with?(".md")
	end
	posts.sort! { |x, y| getPostNumber(x) <=> getPostNumber(y) }
	posts.reverse! # Put newest posts on top
	for i in (0 .. 10)
		if( i >= posts.size )
			break
		end
		begin
			#name = File.basename(posts[i], ".md")
			# TODO: Cache the post names or something so we don't read all the
			# files *twice* to make the RSS feed
			url = posts[i].sub(".md","")
			name = File.open("#{PostsDir}/#{posts[i]}", "r"){ |f| f.readline.gsub("#", "") }
			contents = getMarkdown("posts/" + posts[i])
			xml += "<item>\n"
			xml += "<title>#{name}</title>\n"
			xml += "<link>#{SiteURL}/post/#{url}</link>\n"
			xml += "<description><![CDATA[#{contents}]]></description>\n"
			xml += "</item>\n"
		rescue
			next
		end
	end
	xml += "</channel>\n"
	xml += "</rss>"
end

get '/contact' do
	md = getMarkdown("contact.md")
	erb :markdown, :locals => { :text => md }, :layout => @layout
end

get '/about' do
	md = getMarkdown("about.md")
	erb :markdown, :locals => { :text => md }, :layout => @layout
end
