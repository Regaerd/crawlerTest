require "net/http"
require "uri"
require 'open-uri'

class Crawler
	attr_reader :curURL

	def initialize(startURL)
		$searched = Hash.new
		$downloaded = Hash.new
		$toSearch = Array.new
		$curURL = startURL
		#TODO: grab blacklist and whitelist from database
		$extBlacklist=Array.new
		$extBlacklist.push('.css','.js', '.ico', '.rss', '.php', '.exe', '.swf', '.html', '.htm1', '.pdf')
		#$extWhitelist.push('.jpg', '.png', '.gif', '.webm')
		
		$saveDir = 'downloads/'
		Dir.mkdir($saveDur) unless Dir.exist?($saveDir)
		$logDir = 'logs/'
		Dir.mkdir($logDur) unless Dir.exist?($logDir)
	end
	
	def nothingToSearch?
		return $toSearch.empty?
	end
	
	def autoSearch
		$curURL = nil	
	end
	
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

	def uri?(string)
		uri = URI.parse(string)
		%w( http https ).include?(uri.scheme)
		rescue URI::BadURIError
		false
	rescue URI::InvalidURIError
		false
	end

	def working_url?(url_str)
		url = URI.parse(url_str)
		Net::HTTP.start(url.host, url.port) do |http|
			http.head(url.request_uri).code == '200'
		end
		return true
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

					#get file size
					#TODO find a more efficient way to do this
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
 end