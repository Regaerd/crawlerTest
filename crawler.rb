require "net/http"
require "uri"
require 'open-uri'

class Crawler
	attr_reader :curURL

	def initialize(startURL)
		$searched = Hash.new
		$downloaded = Hash.new
		$toSearch = Array.new
		#TODO: load searched, downloaded, and toSearch from databases if they exist
		@curURL = url_protocol_smart_add(startURL)
		#TODO: grab blacklist and whitelist from a database or text file
		$extBlacklist=['.css','.js', '.ico', '.rss', '.php', '.exe', '.swf', '.html', '.shtm1', '.pdf']
		$extWhitelist=['.jpg', '.png', '.gif', '.webm']
		
		$saveDir = 'downloads/'
		Dir.mkdir($saveDir) unless Dir.exist?($saveDir)
		$logDir = 'logs/'
		Dir.mkdir($logDir) unless Dir.exist?($logDir)
	end
	
	def nothingToSearch?
		return $toSearch.empty?
	end
	
	def autoSearch
		if (url_search(@curURL))
			HashOfArray_smart_add($searched, @curURL)
		end
		$toSearch.shift
		
		if ($toSearch.empty?)
			return false
		else
			@curURL = $toSearch[0]
			return true
		end
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
		#TODO: move code to an error handler
		File.open($logDir+'main.txt', 'a') do |file|
			file.puts "---------------------------------------------------------------------------"
			file.puts curURL
			file.puts e
		end  
		puts "\nEXCEPTION SAVED #{$logDir}main.txt"
		return false
	end

	def url_download(url)
		if (url.match(/^\w+:*\w+\(\'*\d*\'*\);*$/))
			return false
		end
		
		ext = File.extname(URI.parse(url).path)
		if (ext != "")
			if (!url_handled?($downloaded, url))
				HashOfArray_smart_add($downloaded, url)
				#if (!$extBlacklist.include?(ext))
				if ($extWhitelist.include?(ext))
					url.match(/([^\/]*)\.[a-z]+$/)
					
					#get file size
					$file_size
					url_base = url.split('/')[2]
					url_path = '/'+url.split('/')[3..-1].join('/')
					Net::HTTP.start(url_base) do |http|
						response = http.request_head(url_path)
						$file_size = response['content-length'].to_i
					end
					#$mbTotal = $mbTotal + $file_size
					print "\rDownloading: #{url} >> #{bytesToMeg($file_size).round(3)}MB                                                                                     "
					#print "\rDownloading #{@curURL}/#{$1}#{ext} >> #{bytesToMeg($file_size).round(3)}MB                                                                                     "
					STDOUT.flush
	
					#download file
					open($saveDir+$1+ext, 'wb') do |file|
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
		#TODO: move code to an error handler
		File.open($logDir+'down.txt', 'a') do |file|
			file.puts "---------------------------------------------------------------------------"
			file.puts url
			file.puts e
		end  
		puts "\nEXCEPTION SAVED #{$logDir}down.txt"
		return false
	end

	def HashOfArray_smart_add(hash, url)
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
	
	def url_protocol_smart_add(url)
		unless url[/\Ahttp:\/\//] || url[/\Ahttps:\/\//]
			url = "http://#{url}"
		end
	end
	
	MEGABYTE = 1024.0 * 1024.0
	def bytesToMeg(bytes)
		bytes/MEGABYTE  
	end
 end