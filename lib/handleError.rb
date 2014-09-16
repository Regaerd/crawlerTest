class HandleError
	def initialize(dir)
		$activeDir = dir
		Dir.mkdir($activeDir) unless Dir.exist?($activeDir)
	end
	
	def save_to_file(info, error, file)
		File.open($activeDir+file, 'a') do |out|
			out.puts "#Time[#{Time.now}]--------------------"
			out.puts info
			out.puts error
			out.puts
		end  
	rescue => e
		puts e
	end
end