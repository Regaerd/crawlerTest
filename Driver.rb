require 'io/console'	#provides STDIN.getch
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

$killMainThread = false
mainThread = Thread.new do
	puts "Loading..."
	crawler.load_from_file
	loop do
		print "\rSearching: #{crawler.curURL}                                                                                                                           "
		STDOUT.flush
		crawler.autoSearch
		break if ((crawler.nothingToSearch?)||($killMainThread))
	end
	#TODO: store searched and toSearch addresses in databases
	puts "\nSaving..."
	crawler.save_to_file
	puts "Done."
	puts "Press any key to exit."
	mainThread.exit
end

stopThread = Thread.new do
	loop do
		$inputArray << STDIN.getch
		if ($killMainThread)&&($inputArray.join =~ /kill/i)
			mainThread.exit
			stopThread.exit
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
		if (!mainThread.alive?)
			stopThread.exit
		end
	end
end

mainThread.join
stopThread.join