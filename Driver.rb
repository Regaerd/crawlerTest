require 'io/console'	#provides STDIN.getch
require 'thread'

require './lib/crawler'

#Creates a regular expression, using words from a given file and a given option
#On failure returns a default regex
def load_regex_from(file, options)
	pattern = ''
	if (File.exist?(file))
		File.open(file, 'r').each_line do |line|
			words = line.split(/\W+/)
			words.each{|string| string.insert(0, "|")}
			pattern += words.join('')
		end
	end
	pattern[0] = ''
	return Regexp.new(pattern, options)
rescue => e
	puts "Problem loading #{file}"
	puts "HaltWords: x"
	return /x/i
end

#for stopping program
$inputArray = Array.new

print "Starting address: "
crawler = Crawler.new(gets.chomp)
haltWords = load_regex_from("settings/haltWords.txt", "i")

searchT = Thread.new do
	loop do
		Thread.stop
		puts "\nSearching: #{crawler.curURL_Sr}"
		crawler.auto_search
	end
end

downloadT = Thread.new do
	loop do
		Thread.stop
		puts "\nDownloading: #{crawler.curURL_Dl}"
		crawler.auto_download
	end
end

count = 0
$killMainThread = false
mainT = Thread.new do
	puts "Loading..."
	crawler.load_all_from_files
	puts "Done."
	loop do
		if (searchT.stop?)
			if (downloadT.stop?)
				crawler.set_next_download
				downloadT.wakeup
			end
			crawler.set_next_search
			searchT.wakeup
		end
		break if ((crawler.nothingToSearch?)||($killMainThread))
	end
	system "clear" or system "cls"
	puts "\nSaving..."
	crawler.save_all_to_files
	puts "Done."
	puts "Press any key to exit."

	mainT.exit
end

stopT = Thread.new do
	loop do
		$inputArray << STDIN.getch
		if ($killMainThread)&&($inputArray.join =~ /kill/i)
			mainT.exit
			stopT.exit
		elsif ($inputArray.join =~ haltWords)
			$killMainThread = true
			$inputArray.clear
			puts "\nShutting down safely (type 'kill' to force shutdown)"
		elsif ($inputArray.join =~ /pgcount/i)
			$inputArray.clear
			puts "\n----------"
			puts "Total pages to search: #{crawler.pgCount}"
			puts "----------"
		end
		if (!mainT.alive?)
			stopT.exit
		end
	end
end

mainT.join
stopT.join
