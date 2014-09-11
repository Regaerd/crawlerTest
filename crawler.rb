##########
#	Requires
##########
require 'sdbm'		#provides database
require "net/http"
require "uri"
require 'open-uri'

##########
#	Methods
##########
MEGABYTE = 1024.0 * 1024.0
def bytesToMeg(bytes)
  bytes/MEGABYTE  
end

def get_response_with_redirect(uri)
	r = Net::HTTP.get_response(uri)
	if r.code == "301"
		r = Net::HTTP.get_response(URI.parse(r.header['location']))
	end
	r
end

def working_url?(url_str)
  url = URI.parse(url_str)
  Net::HTTP.start(url.host, url.port) do |http|
    http.head(url.request_uri).code == '200'
  end
rescue
  false
end

def url_search(curURL)
	response = get_response_with_redirect(URI.parse(curURL))
	#check each line
	$dlCount = 0
	$pgCount = 0
	if (response.code != "404")
		response.body.each_line{|line|
			#get any href
			results = line.scan(/href="([^"]*)"/)
			results.each{|href|
				url = URI.join(curURL, href[0]).to_s
				url_download(url)
			}
		}
	end
	return true
rescue => e
	puts "\nEXCEPTION IN MAIN LOOP ON: #{curURL}\n#{e}"
	return false
end

def url_download(url)
	if (url.match(/^\w+:*\w+\(\'*\d*\'*\);*$/))
		return false
	end
	
	ext = File.extname(URI.parse(url).path)
	if (ext != "")
		if (!url_handled?($downloaded, url))
			url_safeAdd_Hash($downloaded, url)
			if (!$extBlacklist.include?(ext))
				url.match(/([^\/]*)\.[a-z]+$/)

				#get file size
				$file_size
				url_base = url.split('/')[2]
				url_path = '/'+url.split('/')[3..-1].join('/')
				Net::HTTP.start(url_base) do |http|
					response = http.request_head(url_path)
					$file_size = response['content-length'].to_i
				end
				$mbTotal = $mbTotal + $file_size
				print "\rdl #{$1}#{ext} >> #{bytesToMeg($file_size).round(3)}MB                            "
				STDOUT.flush
				#download file
				open($saveDur+$1+ext, 'wb') do |file|
					file<<open(url).read
				end
				$dlCount = $dlCount+1 
			end			
		end
	else
		if (!url_handled?($searched, url))
			$toSearch.push(url)
			$pgCount = $pgCount+1
		end		
	end
	return true
rescue => e
	puts "\nEXCEPTION ON: #{url}\n#{e}"
	return false
end

def url_safeAdd_Hash(hash, url)
	offset = url.index('.')
	key = url[offset]
	if (!hash.has_key?(key))
		hash[key]=Array.new
	elsif (hash[key].include?(url))
		return
	end
	hash[key].push(url)
end

def url_handled?(hash, url)
	offset = url.index('.')
	key = url[offset]
	return(hash.has_key?(key) && hash[key].include?(url))
end

##########
#	Global Variables
##########
$curWebsite = "http://google.com/"
$curURL = $curWebsite
$searched = Hash.new
$downloaded = Hash.new
$toSearch = Array.new
$extBlacklist = Array.new
$extWhitelist = Array.new

$toSearch.push($curURL)
$extBlacklist.push('.css','.js', '.ico', '.rss', '.php', '.exe', '.swf', '.html', '.htm', '.pdf')
$extWhitelist.push('.jpg', '.png', '.gif', '.webm')

$saveDur = 'downloaded/'
Dir.mkdir($saveDur) unless Dir.exist?($saveDur)

$mbTotal = 0
$dlCount = 0
$pgCount = 0

##########
#	Begin Main Loop
##########
puts 'Starting main loop'
loop do
	puts "\n=====[#{$curURL}]====="
	#grab page from url
	if (url_search($curURL))
		print "\r#{$pgCount} Pages (Total: #{$toSearch.size})| #{$dlCount} Files (Total: #{bytesToMeg($mbTotal).round(3)}MB)                  "
		url_safeAdd_Hash($searched, $curURL)
	end
	
	$toSearch.shift
	break if ($toSearch.empty?)
	$curURL = $toSearch[0]
end
puts 'Done'
