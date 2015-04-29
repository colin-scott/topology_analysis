require_relative 'config.rb'
require_relative 'retrieve_data.rb'
require_relative 'lib/traceroute_reader_util.rb'

module Latency

def self.analyze(options)
    if options[:duration].nil?
        puts "No duration is given."
        exit
    end

    startdate = options[:start]
    puts "Duration: #{duration} days"

    numday = 0
    latency_aggr = Hash.new

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1
        
        tracelist = retrieve_yahoo(date)
        selected_vps = select_yahoo_vps(tracelist.keys)
        puts "[#{Time.now}] Start the analysis on #{date} from #{selected_vps.size} nodes"

        selected_vps.each do |vp|
            filelist = tracelist[vp]
            localfilelist = download_yahoo_data(filelist)
            reader = YahooTRFileReader.new(localfilelist)
            reader.each do |tr|
                next if tr.dst != tr.hops[-1][0]

    end
end
end
