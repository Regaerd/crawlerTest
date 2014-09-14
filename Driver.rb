require 'sdbm'			#provides databases
require 'io/console'	#provides STDIN.getch

require './crawler'

#input queue
$iQUEUE = Array.new

print "Starting address: "
crawler = Crawler.new(gets)
haltWords = /exit|stop|kill|x|q|quit|end/i

#mainThread = Thread.new{sleep}
#stopThread = Thread.new{sleep}

$killMainThread = false
mainThread = Thread.new do
	puts 'Starting main loop'
	loop do
		puts "\nSearching: #{crawler.curURL}]"
		crawler.autoSearch
		break if ((crawler.nothingToSearch?)||($killMainThread))
	end
	puts "\n\nStopping main loop"
end

stopThread = Thread.new do
	loop do
		$iQUEUE << STDIN.getch
		if ($iQUEUE.join =~ haltWords)
			$killMainThread = true
			puts "\n==========Shutting down ASAP==================="
			stopThread.exit
		elsif (!mainThread.alive?)
			puts "\n==========Shutting down: no more work=========="
			stopThread.exit
		end
	end
end

mainThread.join
stopThread.join
puts "Closing"