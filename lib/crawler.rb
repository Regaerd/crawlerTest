require "net/http"
require "uri"
require 'open-uri'
require './lib/handleError'

#TODO: read robots.txt
#TODO: gather any url found in plain text on a page
#TODO: settings: ignore robots.txt
#				 avoid addresses containing '#' or '?'
#				 different search techniques
#				 download blacklist for favicon and icon

class Crawler
	attr_reader :curURL_Sr
	attr_reader :curURL_Dl
	attr_reader :pgCount

	def initialize(startURL)
		$searched = Hash.new
		$downloaded = Hash.new
		$toSearch = Array.new 
		$toDownload = Array.new
		
		$invalid_Sr = /#|\?/ 			#TODO: get values from file
		$invalid_Dl = /icon|flavicon/	#TODO: get values from file
		
		$toSearch.push(url_protocol_smart_add(startURL))

		@curURL_Sr = nil	#url currently being searched
		@curURL_Dl = nil	#url currently being downloaded
		
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
		$specialErrorTxt = "specialErrors.txt"
		$error = HandleError.new("data/logs/")
	end
	
	#save progress to files
	def save_all_to_files
		save_hash_to_file($searched, $progDir+'searched.txt')
		save_hash_to_file($downloaded, $progDir+'downloaded.txt')
		save_array_to_file($toSearch, $progDir+'toSearch.txt')
		save_array_to_file($toDownload, $progDir+'toDownload.txt')
		@pgCount=$toSearch.size
	rescue => e
		$error.save_error_to_file(__method__, e, $specialErrorTxt)
	end
	
	#load progress files into program
	def load_all_from_files
		load_hash_from_file($searched, $progDir+'searched.txt')
		load_hash_from_file($downloaded, $progDir+'downloaded.txt')
		load_array_from_file($toSearch, $progDir+'toSearch.txt')
		load_array_from_file($toDownload, $progDir+'toDownload.txt')
	rescue => e
		$error.save_error_to_file(__method__, e, $specialErrorTxt)
	end
	
	#return whether or not there is anything left to search
	def nothingToSearch? 
		return $toSearch.empty? 
	end
	
	#
	def set_next_search 
		@curURL_Sr = set_next($toSearch) 
	end
	
	#
	def set_next_download 
		@curURL_Dl = set_next($toDownload)
	end
	
	#
	def set_next(array)
		if (array.empty?)
			return nil
		else
			return array[0]
		end	
	end
	
	#TODO: simplify methods after testing is done
	#automatically go through and search one url and set up for the next search
	def auto_search
		if (@curURL_Sr != nil)
			url_search(@curURL_Sr)
			HashOfArray_smart_add($searched, @curURL_Sr)
			$toSearch.shift
			return true
		end
		return false
	end
	
	#
	def auto_download
		if (@curURL_Dl != nil)
			url_download(@curURL_Dl)
			HashOfArray_smart_add($downloaded, @curURL_Dl)
			$toDownload.shift
			return true
		end
		return false
	end
	
	#search the given url
	def url_search(url)
		response = get_response_with_redirect(URI.parse(url))
		if (response.code != "404")
			response.body.each_line{|line|
				results = line.scan(/href="([^"]*)"/)
				results.each{|href|
					found = URI.join(url, href[0]).to_s
					url_eval(found)
				}
				#TODO: find urls that are in plain text, not just href
			}
		end
		return true
	rescue => e
		$error.save_error_to_file(url, e, $majorErrorTxt)
		return false
	end
	
	#try to download from the given url. assuming it is a file
	def url_download(url)
		ext = File.extname(URI.parse(url).path)
			url.match(/([^\/]*)\.[a-z]+$/)
			open($fileDir+$1+ext, 'wb') do |file|
				file<<open(url).read
			end
=begin				#code for displaying file size
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
=end

		
	rescue => e
		$error.save_error_to_file(url, e, $minorErrorTxt) #TODO possibly replace url with an array of relevant information
		return false
	end

	#evaluate what a url is and sort it
	def url_eval(url)
		if (url.match(/^\w+:*\w+\(\'*\d*\'*\);*$/))
			return false
		end
		
		ext = File.extname(URI.parse(url).path)
		if (ext != "")
			if ((!url.match($invalid_Dl))&&(!url_handled?($downloaded, url))&&(!$toDownload.include?(url))&&(($extWhitelist.empty?)||($extWhitelist.include?(ext))))
				$toDownload.push(url)			
			end
		else
			if ((!url.match($invalid_Sr))&&(!url_handled?($searched, url))&&(!$toSearch.include?(url)))
				$toSearch.push(url)
				@pgCount += 1
			end		
		end
		return true
	rescue => e
		$error.save_error_to_file(url, e, $minorErrorTxt)
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
	
	#check if website works, and redirect if necessary
	def get_response_with_redirect(uri)
		response = Net::HTTP.get_response(uri)
		if response.code == "301"
			response = Net::HTTP.get_response(URI.parse(response.header['location']))
		end
		response
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
	
	def save_hash_to_file(hash, file)
		File.open(file, 'w') do |out|
			hash.each_key{|key|
				hash[key].each{|value|
					out.puts value
				}
			}
		end
	end
	
	def save_array_to_file(array, file)
		File.open(file, 'w') do |out|
			array.each{|value|
				out.puts value
			}
		end
	end
	
	def load_hash_from_file(hash, file)
		if (File.exist?(file))
			File.open(file, 'r').each_line do |line|
				HashOfArray_smart_add(hash, line.chomp!)
			end
		end
	end
	
	def load_array_from_file(array, file)
		if (File.exist?(file))
			File.open(file, 'r').each_line do |line|
				array.push(line.chomp!)
			end
		end
	end
	
 end