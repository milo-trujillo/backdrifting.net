#!/usr/local/bin/ruby
# encoding: UTF-8
require 'sinatra'
require 'tilt/erb'
require 'kramdown'

#$renderer = Redcarpet::Render::HTML.new()
#$markdown = Redcarpet::Markdown.new($renderer, extensions = {})
Private = File.dirname(__FILE__) + "/private"
PostsDir = Private + "/posts"
PreviewDir = Private + "/preview"
PreviewPassword = ""
PostSeparator = "\n<hr>\n"
Description = "Digital Haven"
FeedSize = 10 # How many posts to put in the RSS

before '*' do
	if( request.url.start_with?("http://") )
		redirect to (request.url.sub("http", "https"))
	end
end

# Make all requests to non-existant pages give our 404 page
error Sinatra::NotFound do
	erb :notfound
end

# And do the same if one of our functions throws a 404
not_found do
	status 404
	erb :notfound
end

def getMarkdown(filename)
	begin
		f = File.open(Private + "/" + filename, "r")
		md = Kramdown::Document.new(f.read).to_html
		f.close
		return md
	rescue
		return ""
	end
end

# To sort posts numerically we need to get their number
# This is everything up to the "_", converted to an int
def getPostNumber(filename)
	return filename[/^(.+)_/].to_i
end

# Renders the markdown for a post and generates appropriate 'sharing' buttons
def renderPost(postfilename)
	postname = File.basename(postfilename, ".md")
	text = getMarkdown("posts/" + postfilename)
	if( text.length == 0 ) # No post, so don't add the share buttons
		return text
	end

	share = <<SHARE_END
<ul class="share-buttons">
  <li><a href="https://twitter.com/intent/tweet?share=https%3A%2F%2Fbackdrifting.net%2Fpost%2F#{postname}" target="_blank" title="Tweet"><img src="/share/twitter.png" width=24px></a></li>
  <li><a href="http://www.reddit.com/submit?url=https%3A%2F%2Fbackdrifting.net%2Fpost%2F#{postname}&title=Backdrifting" target="_blank" title="Submit to Reddit"><img src="/share/reddit.png" width=24px></a></li>
  <li><a href="mailto:?subject=Backdrifting&body=https%3A%2F%2Fbackdrifting.net%2Fpost%2F#{postname}" target="_blank" title="Email"><img src="/share/email.png" width=24px></a></li>
  <li><a href="/post/#{postname}" target="_blank" title="Permalink"><img src="/share/pin.png" width=24px></a></li>
</ul>
SHARE_END

	text += share
	return text
end

get '/' do
	intro = getMarkdown("introduction.md")
	text = ""
	posts = Dir.entries(PostsDir).select do |f| 
		File.file?(PostsDir + "/" + f) and f.end_with?(".md")
	end
	posts.sort! { |x, y| getPostNumber(x) <=> getPostNumber(y) }
	for post in posts.reverse[0..4]
		text += (renderPost(post) + PostSeparator)
	end
	erb :frontpage, :locals => { :intro => intro, :text => text }
end

get '/allPosts' do
	text = ""
	posts = Dir.entries(PostsDir).select do |f| 
		File.file?(PostsDir + "/" + f) and f.end_with?(".md")
	end
	posts.sort! { |x, y| getPostNumber(x) <=> getPostNumber(y) }
	for post in posts.reverse
		text += (renderPost(post) + PostSeparator)
	end
	erb :markdown, :locals => { :text => text }
end

get '/secretPreviews/:password' do |password|
	pause = rand(0.0 .. 1.0)
	sleep(pause)
	if( password == PreviewPassword )
		text = ""
		posts = Dir.entries(PreviewDir).select do |f| 
			File.file?(PreviewDir + "/" + f) and f.end_with?(".md")
		end
		for post in posts.reverse
			text += (getMarkdown("preview/" + post) + "\n<hr>\n")
		end
		erb :markdown, :locals => { :text => text }
	else
		return "ACCESS DENIED"
	end
end

get '/archive' do
	filenames = Dir.entries(PostsDir).select do |f|
		File.file?(PostsDir + "/" + f) and f.end_with?(".md")
	end
	filenames.sort! { |x, y| getPostNumber(x) <=> getPostNumber(y) }
	filenames.reverse! # Put newest posts on top
	posts = []
	for file in filenames
		firstLine = File.open("#{PostsDir}/#{file}", "r"){ |f| f.readline }
		articleName = firstLine.gsub("#", "")
		posts.push([File.basename(file, ".md"), articleName])
	end
	erb :archive, :locals => { :posts => posts }
end

get '/post/:name' do |name|
	if( name =~ /[^A-Za-z0-9_]/ )
		halt 404
	end
	if( File.exists?(PostsDir + "/" + name + ".md") )
		erb :markdown, :locals => { :text => renderPost(name + ".md") }
	else
		halt 404
	end
end

get '/rss' do
	xml = <<END_XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
<channel>
<title>Backdrifting</title>
<link>https://www.backdrifting.net/</link>
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
			name = File.open("#{PostsDir}/#{posts[i]}", "r"){ |f| f.readline.gsub("#", "") }
			contents = getMarkdown("posts/" + posts[i])
			xml += "<item>\n"
			xml += "<title>#{name}</title>\n"
			xml += "<link>backdrifting.net/post/#{name}</link>\n"
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
	erb :markdown, :locals => { :text => md }
end

get '/about' do
	md = getMarkdown("about.md")
	erb :markdown, :locals => { :text => md }
end
