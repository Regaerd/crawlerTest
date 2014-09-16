require "net/http"
require "uri"
require 'open-uri'
require './lib/handleError'

class Crawler
	attr_reader :curURL
	attr_reader :pgCount

	def initialize(startURL)
		$searched = Hash.new
		$downloaded = Hash.new
		$toSearch = Array.new

		@curURL = url_protocol_smart_add(startURL)
		
		@pgCount=0

		$extWhitelist=Array.new
		if (File.exist?('settings/whitelist.txt'))
			File.open('settings/whitelist.txt', 'r').each_line do |line|
				exts = line.split(/\W+/)
				exts.each{|string| string.insert(0, ".")}
				$extWhitelist.concat(exts)
			end
		end
		
		$dataDir = "data/"
		Dir.mkdir($dataDir) unless Dir.exist?($dataDir)
		$fileDir = "data/files/"
		Dir.mkdir($fileDir) unless Dir.exist?($fileDir)
		$progDir = "data/prog/"
		Dir.mkdir($progDir) unless Dir.exist?($progDir)

		
		$minorErrorTxt = "minorErrors.txt"
		$majorErrorTxt = "majorErrors.txt"
		$error = HandleError.new("data/logs/")
	end
	
	#save progress to files
	def save_to_file
		File.open($progDir+'searched.txt', 'w') do |out|
			$searched.each_pair{|key,val|
				$searched[key].each{|value|
					out.puts value
				}
			}
		end
		File.open($progDir+'downloaded.txt', 'w') do |out|
			$downloaded.each_pair{|key,val|
				$downloaded[key].each{|value|
					out.puts value
				}
			}
		end
		File.open($progDir+'toSearch.txt', 'w') do |out|
			$toSearch.each{|value|
				out.puts value
			}
		end 
	rescue => e
		puts "Saving Failed!"
		puts e
	end
	
	#load progress file into program
	def load_from_file
		workingDir = $progDir+'searched.txt'
		if (File.exist?(workingDir))
			File.open(workingDir, 'r').each_line do |line|
				HashOfArray_smart_add($searched, line.chomp!)
			end
		end
		workingDir = $progDir+'downloaded.txt'
		if (File.exist?(workingDir))
			File.open(workingDir, 'r').each_line do |line|
				HashOfArray_smart_add($downloaded, line.chomp!)
			end
		end
		workingDir = $progDir+'toSearch.txt'
		if (File.exist?(workingDir))
			File.open(workingDir, 'r').each_line do |line|
				$toSearch.push(line.chomp!)
			end
		end
	end
	
	#return whether or not there is anything left to search
	def nothingToSearch?
		return $toSearch.empty?
	end
	
	#automatically go through and search one url and set up for the next search
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

	#check if website works, and redirect if necessary
	def get_response_with_redirect(uri)
		response = Net::HTTP.get_response(uri)
		if response.code == "301"
			response = Net::HTTP.get_response(URI.parse(response.header['location']))
		end
		response
	end
	
	#search the given url
	def url_search(curURL)
		response = get_response_with_redirect(URI.parse(curURL))
		if (response.code != "404")
			response.body.each_line{|line|
				results = line.scan(/href="([^"]*)"/)
				results.each{|href|
					url = URI.join(curURL, href[0]).to_s
					url_download(url)
				}
			}
		end
		return true
	rescue => e
		$error.save_to_file(curURL, e, $majorErrorTxt)
		puts "\nEXCEPTION SAVED #{$logDir}#{$majorErrorTxt}"
		return false
	end

	#download from given url if possible
	def url_download(url)
		if (url.match(/^\w+:*\w+\(\'*\d*\'*\);*$/))
			return false
		end
		
		ext = File.extname(URI.parse(url).path)
		if (ext != "")
			if (!url_handled?($downloaded, url))
				HashOfArray_smart_add($downloaded, url)
				#if (!$extBlacklist.include?(ext))
				if (($extWhitelist.empty?)||($extWhitelist.include?(ext)))
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
					STDOUT.flush
	
					#download file
					open($fileDir+$1+ext, 'wb') do |file|
						file<<open(url).read
					end
				end			
			end
		else
			if (!url_handled?($searched, url))&&(!$toSearch.include?(url))
				$toSearch.push(url)
				@pgCount += 1
			end		
		end
		return true
	rescue => e
		$error.save_to_file(curURL, e, $minorErrorTxt)
		puts "\nEXCEPTION SAVED #{$logDir}#{$minorErrorTxt}"
		return false
	end

	#store given url in a hash in a organized fashion
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

	#check if url is in organized hash
	def url_handled?(hash, url)
		offset = url.index('.')
		key = url[offset]
		return(hash.has_key?(key) && hash[key].include?(url))
	end
	
	#add protocol to given url if it has none
	def url_protocol_smart_add(url)
		unless url[/\Ahttp:\/\//] || url[/\Ahttps:\/\//]
			url = "http://#{url}"
		end
	end
	
	#convert given bytes to megabytes
	def bytesToMeg(bytes)
		bytes/1048576.0 #bytes/(1024*1024) = MB
	end
 end