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

            firsthop = nil
            index_file, trace_file = download_iplane_data(date, uris)
            reader = IPlaneTRFileReader.new(index_file, trace_file)
            output = trace_file.sub('trace.out', 'astrace').sub('.gz', '')

            puts "[#{Time.now}] Converting #{trace_file}"
            convert_to_as_trace(reader, output, firsthop, targets)
            puts "[#{Time.now}] Output AS trace file #{output}"
       end
    end

    puts "[#{Time.now}] Program ends"
end
end
