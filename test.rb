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
	File.open($logDur+'main.txt', 'a') do |file|
		file.puts "---------------------------------------------------------------------------"
		file.puts curURL
		file.puts e
	end  
	puts "\nEXCEPTION SAVED"
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
			#if (!$extBlacklist.include?(ext))
			if ($extWhitelist.include?(ext))
				url.match(/([^\/]*)\.[a-z]+$/)

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
	File.open($logDur+'down.txt', 'a') do |file|
		file.puts "---------------------------------------------------------------------------"
		file.puts url
		file.puts e
	end  
	puts "\nEXCEPTION SAVED"
	return false
end

#TODO: keep is array organized
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
$curWebsite = "http://www.google.com/"

$curURL = $curWebsite
$searched = Hash.new
$downloaded = Hash.new
$toSearch = Array.new
$extBlacklist = Array.new
$extWhitelist = Array.new

$toSearch.push($curURL)
$extBlacklist.push('.css','.js', '.ico', '.rss', '.php', '.exe', '.swf', '.html', '.htm1', '.pdf')
$extWhitelist.push('.jpg', '.png', '.gif', '.webm')

$saveDur = 'downloads/'
Dir.mkdir($saveDur) unless Dir.exist?($saveDur)

$logDur = 'logs/'
Dir.mkdir($logDur) unless Dir.exist?($logDur)

$mbTotal = 0
$dlCount = 0
$pgCount = 0
$killMainThread = false

mainThread = Thread.new do
	puts 'Starting main loop'
	loop do
		puts "\n=====[#{$curURL}]====="
		#grab page from url
		if (url_search($curURL))
			print "\r#{$pgCount} Pages (Total: #{$toSearch.size})| #{$dlCount} Files (Total: #{bytesToMeg($mbTotal).round(3)}MB)                  "
			url_safeAdd_Hash($searched, $curURL)
		end
		
		$toSearch.shift
		break if ($toSearch.empty?)||$killMainThread
		$curURL = $toSearch[0]
	end
	puts "\n\nStopping main loop"
	mainThread.exit
end

stopThread = Thread.new do
	loop do
        if (gets =~ /exit|stop|kill|x|quit|end/i)
			$killMainThread = true
			puts "==========Shutting down ASAP=========="
			stopThread.exit
		end
	end
end

mainThread.join
stopThread.join
puts "closing"
