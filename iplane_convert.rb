require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'lib/astrace.rb'

include TopoConfig

module Converter
def self.convert(options)
    if options[:duration].nil?
        put "No duration is given."
        exit
    end

    startdate = options[:start]
    duration = options[:duration]
    puts "Duration: #{duration} days"

    numday = 0
    targets = load_target_list

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1

        tracelist = retrieve_iplane(date)
        puts "[#{Time.now}] Start the analysis on #{date}"

        tracelist.each do |vp, uris|
            next if skip_iplane?(vp)
            puts "[#{Time.now}] Processing data from #{vp}"
            # download raw traceroute data
            download_iplane_data(date, uris)
            # convert to astrace data
            get_iplane_astrace_file(date, uris)
        end
    end

    puts "[#{Time.now}] Program ends"
end
end
