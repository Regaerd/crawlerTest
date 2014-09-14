#require 'sdbm'			#provides databases
require 'io/console'	#provides STDIN.getch
require './crawler'

#for stopping program
$inputArray = Array.new

print "Starting address: "
crawler = Crawler.new(gets.chomp)
haltWords = /exit|stop|kill|x|q|quit|end/i	#TODO: get halt words from a text file

$killMainThread = false
mainThread = Thread.new do
	loop do
		print "\rSearching: #{crawler.curURL}                                                                                                                           "
		STDOUT.flush
		crawler.autoSearch
		break if ((crawler.nothingToSearch?)||($killMainThread))
	end
	#TODO: store searched and toSearch addresses in databases
	puts "\nStopping main loop, press any key to exit"
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
		end
		if (!mainThread.alive?)
			stopThread.exit
		end
	end
end

mainThread.join
stopThread.join