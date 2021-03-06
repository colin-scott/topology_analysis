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

    vp_info = load_yahoo_vp_info
    numday = 0

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1

        tracelist = retrieve_yahoo(date)
        puts "[#{Time.now}] Start the convert on #{date}"

        tracelist.each do |vp, filelist|
            puts "[#{Time.now}] Processing data from #{vp}"
            # make sure we also download all traceroute file
            download_yahoo_data(filelist)
            # convert the trace file to astrace file
            # use the vp_ip for the missing 1st hops since 1st hop is always within CDN
            vp_ip, vp_asn = vp_info[vp]
            astrace_filelist = get_yahoo_astrace_filelist(filelist, vp_ip)
        end
    end

    puts "[#{Time.now}] Program ends"
end
end
