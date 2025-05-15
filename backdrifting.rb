#!/usr/local/bin/ruby
# encoding: UTF-8
require 'time'
require 'date'
require 'sinatra'
require 'tilt/erb'
require 'pathname'
require 'kramdown'
require 'kramdown-syntax-coderay'
require 'rack/mobile-detect'
use Rack::MobileDetect

Public = File.dirname(__FILE__) + "/public"
Private = File.dirname(__FILE__) + "/private"
PostsDir = Private + "/posts"
PreviewDir = Private + "/preview"
PreviewPassword = ""
ShareablePreviewPassword = ""
#PostSeparator = "\n<center><hr></center>\n"
PostSeparator = "\n<br />\n"
SiteName = ""
SiteURL = ""
SiteDomains = ["example.com", "www.example.com"]
TwitterHandle = "@foo"
SocialMediaImageURL = "/images/qr.png"
Description = "Digital Haven"
Author = ""
ForceTLS = false # Apache/nginx may already do this with a redirect
AnalyticsEnabled = false
AnalyticsDatabaseURL = "redis://127.0.0.1:6379/"
AnalyticsPassword = ""

SiteMetaData = <<METADATA_END
<meta name="twitter:card" content="summary" />
<meta name="twitter:site" content="#{TwitterHandle}" />
<meta name="twitter:title" content="#{Description}" />
<meta name="twitter:image" content="#{SiteURL + SocialMediaImageURL}" />
METADATA_END

before '*' do
	if( ForceTLS and request.url.start_with?("http://") )
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
				realpage = page.split("?")[0] # Strip "?fbclid=AksASF..."
				realpage = CGI::unescape(realpage) # %5f -> _
				redis.hincrby("pagehits", realpage, 1)
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
		erb :analytics, :locals => {:pagetitle => "#{SiteName} Analytics", :pagehits => pagehits, :referrers => referrers}, :layout => @layout
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

#
# Helper functions for rendering posts
#
def getMarkdown(filename)
	begin
		# Attach a prefix to auto-generated hyperlinks like footnotes,
		# so that a page containing multiple posts with footnotes won't have
		# any conflicts
		prefix = Pathname.new(filename).basename.to_s.split(".")[0] + "_"
		f = File.open(Private + "/" + filename, "r")
		md = Kramdown::Document.new(f.read, {:footnote_prefix=>prefix, :syntax_highlighter=>:coderay, :syntax_highlighter_opts=>{:line_numbers=>nil}}).to_html
		f.close
		return md
	rescue
		return ""
	end
end

# Extracts first <h2> tag, strips inner html (like italics)
def getTitleFromPostHTML(html)
	return html.match(/<h2[^>]*>(.+)<\/h2>/)[1].gsub(/<[^>]*>/, "")
end

def getDateFromPostHTML(html)
	string = html.match(/>Posted (.+)/)[1]
	m,d,y = string.split("/").map {|f| f.to_i}
	if( y < 2000 )
		y += 2000
	end
	return Time.new(y, m, d).to_s
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
<div id="blogpost">
<meta name="twitter:card" content="summary" />
<meta name="twitter:site" content="#{TwitterHandle}" />
<meta name="twitter:title" content="#{title}" />
<meta name="twitter:image" content="#{SiteURL + SocialMediaImageURL}" />
METADATA_END

	encodedURL = ERB::Util.url_encode(SiteURL + "/post/")
	share = <<SHARE_END
<ul class="share-buttons">
  <li><a href="/post/#{postname}" target="_blank" title="Permalink">Permalink</a></li>
</ul>
SHARE_END

	footer = "</div>" # Ends "blogpost"

	renderedPost = header + text + footer + share
	return renderedPost
end

#
# Pre-load and render all posts
#
$posts = Hash.new()
$postTitles = Hash.new()
$postDates = Hash.new()
posts = Dir.entries(PostsDir).select do |f| 
	File.file?(PostsDir + "/" + f) and f.end_with?(".md")
end
for post in posts
	$posts[post] = renderPost(post)
	$postTitles[post] = getTitleFromPostHTML($posts[post])
	$postDates[post] = getDateFromPostHTML($posts[post])
end
$allposts = ""
$frontpage = ""
posts = $posts.keys.sort { |x,y| getPostNumber(x) <=> getPostNumber(y) }
posts.reverse.each_with_index do |post, i|
	if( i < 5 )
		$frontpage += ($posts[post] + PostSeparator)
	end
	$allposts += ($posts[post] + PostSeparator)
end
$topicmap = File.read(Public+"/topicmap.svg")

get '/' do
	erb :frontpage, :locals => { :text => $frontpage, :pagetitle => "#{SiteName}: #{Author}'s Cyber-Nest", :pagedescription => Description, :sitemetadata => SiteMetaData }, :layout => @layout
end

get '/mobiletest' do
	text = ""
	posts = $posts.keys.sort { |x,y| getPostNumber(x) <=> getPostNumber(y) }
	for post in posts.reverse[0..4]
		text += ($posts[post] + PostSeparator)
	end
	erb :frontpage, :locals => { :text => text }, :layout => :layout_mobile
end

# Generate a sitemap to improve coverage by search engines
get '/robots.txt' do
	content_type 'text/plain'
	return "Sitemap: #{SiteURL}/sitemap.txt\nUser-agent: *\nAllow: /"
end
get '/sitemap.txt' do
	content_type 'text/plain'
	map  = "#{SiteURL}/\n"
	map += "#{SiteURL}/about\n"
	map += "#{SiteURL}/contact\n"
	map += "#{SiteURL}/archive\n"
	for post in $posts.keys
		# Remember to strip the ".md" off the end
		map += "#{SiteURL}/post/#{post[0..-4]}\n"
	end
	return map
end

get '/allPosts' do
	erb :markdown, :locals => { :text => $allposts, :pagetitle => "All #{Author}'s Posts", :pagedescription => "Every blog post on one page" }, :layout => @layout
end

get '/secretPreviews/' + PreviewPassword do
	text = ""
	posts = Dir.entries(PreviewDir).select do |f| 
		File.file?(PreviewDir + "/" + f) and f.end_with?(".md")
	end
	hdr = "<div id=\"blogpost\">\n"
	ftr = "</div>\n<hr>\n"
	for post in posts.sort.reverse
		postname = post.split(".")[0]
		share = <<ENDSHARE
<ul class="share-buttons">
  <li><a href="/secretPreviews/#{ShareablePreviewPassword}/#{postname}" target="_blank" title="Permalink"><img src="/share/pin.png" width=24px></a></li>
</ul>
ENDSHARE
		text += hdr + getMarkdown("preview/" + post) + share + ftr
	end
	erb :markdown, :locals => { :text => text }, :layout => @layout
end

get '/secretPreviews/' + ShareablePreviewPassword + '/:name' do |name|
	posts = Dir.entries(PreviewDir).select do |f| 
		File.file?(PreviewDir + "/" + f) and f.end_with?(".md")
	end
	if( posts.include?(name + ".md") )
		hdr = "<div id=\"blogpost\">\n"
		ftr = "</div>\n<hr>\n"
		text = hdr + getMarkdown("preview/" + name + ".md") + ftr
		erb :markdown, :locals => { :text => text }, :layout => @layout
	else
		halt 404
	end
end

get '/archive' do
	filenames = $posts.keys.sort { |x,y| getPostNumber(x) <=> getPostNumber(y) }
	posts = []
	for file in filenames.reverse
		articleName = $postTitles[file]
		#articleDate = Time.parse($postDates[file]).strftime("%m/%d/%y")
		articleDate = Time.parse($postDates[file]).strftime("%b %d, %Y")
		posts.push([articleDate, File.basename(file, ".md"), articleName])
	end
	erb :archive, :locals => { :posts => posts, :topicmap => $topicmap, :pagetitle => "Archive of #{Author}'s Posts", :pagedescription => "An index of all blog posts" }, :layout => @layout
end

get '/post/:name' do |name|
	if( name =~ /[^A-Za-z0-9_]/ )
		halt 404
	end
	postName = name + ".md"
	if( $posts.keys.include?(postName) )
		erb :post, :locals => { :text => $posts[postName], :pagetitle => $postTitles[postName], :pagedescription => $postTitles[postName], :post_date => $postDates[postName], :author_name => Author, :site_url => SiteURL }, :layout => @layout
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
	posts = $posts.keys.sort { |x,y| getPostNumber(x) <=> getPostNumber(y) }
	posts.reverse.each_with_index do |postname, i|
		begin
			name = File.basename(posts[i], ".md")
			# TODO: Cache the post names or something so we don't read all the
			# files *twice* to make the RSS feed
			url = postname.sub(".md","")
			name = $postTitles[postname]
			contents = $posts[postname]
			date = Date.strptime($postDates[postname]).rfc2822()
			xml += "<item>\n"
			xml += "<title>#{name}</title>\n"
			xml += "<link>#{SiteURL}/post/#{url}</link>\n"
			xml += "<pubDate>#{date}</pubDate>\n"
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
	erb :markdown, :locals => { :text => md, :pagetitle => "Contact #{Author}", :pagedescription => "Contact #{Author}" }, :layout => @layout
end

get '/about' do
	md = getMarkdown("about.md")
	erb :about, :locals => { :text => md, :pagetitle => "About #{Author}", :pagedescription => "Bio and profile of #{Author}" }, :layout => @layout
end

get '/publications' do
	acpubs = getMarkdown("academic.md").split("<hr />")
	nonpubs = getMarkdown("nonpeerreviewed.md").split("<hr />")
	lecs = getMarkdown("lectures.md").split("<hr />")
	media = getMarkdown("media.md").split("<hr />")
	erb :publications, :locals => { :academic => acpubs, :nonpeerreviewed => nonpubs, :lectures => lecs, :media => media, :pagetitle => "#{Author}'s Publications", :pagedescription => "Publications of #{Author}" }, :layout => @layout
end
