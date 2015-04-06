require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'lib/analysis'

def load_yahoo_aslist
    aslist = Set.new
    File.open('yahoo_asns.csv').each do |line|
        next if not line =~ /^\d/
        asn = line.split(',')[1].to_i
        aslist << asn if asn < 64496 # don't include private asn
    end
    aslist
end

if $0 == __FILE__
    options = {}
    optparse = OptionParser.new do |opts|
        options[:start] = nil
        opts.on("-s", "--start DATE", "Specify the start date (format: 20150101)") do |start|
            options[:start] = Date.parse(start)
        end
        options[:duration] = nil
        opts.on("-d", "--duration DURATION", "Sepcify the duration of days (format: 1d, 5d, 1w)") do |duration|
            if duration.end_with?('d')
                options[:duration] = duration.chomp('d').to_i
            elsif duration.end_with?('w')
                options[:duration] = duration.chomp('w').to_i * 7
            else
                puts "Wrong option for duration: #{duration}"
                exit
            end
        end
        opts.on("-h", "--help", "Prints this help") do 
            puts opts
            exit
        end
    end
    optparse.parse!
    if options[:start].nil?
        puts "No start date is given."
        exit
    elsif options[:duration].nil?
        put "No duration is given."
        exit
    end

    startdate = options[:start]
    duration = options[:duration]
    
    puts "Duration: #{duration} days"

    numday = 0
    yahoo_aslist = load_yahoo_aslist
    stats = Analysis.new
    stats.yahoo_aslist = yahoo_aslist

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1

        tracelist = retrieve_yahoo(date)
        tracedir = TopoConfig::YAHOO_DATA_DIR

        puts "[#{Time.now}] Start the analysis on #{date}"
        tracelist.each do |vp, filelist|
            puts "[#{Time.now}] Processing data from #{vp}"

            filelist.each do |fn|
                localfn = File.join(tracedir, fn)
                localfn_ = localfn.gsub(".gz", "")
                next if File.exist? localfn or File.exist? localfn_
                remote_uri = TopoConfig::YAHOO_DATA_URI + fn
                puts "[#{Time.now}] Downloading #{fn}"
                `scp #{remote_uri} #{tracedir}`
            end
            filelist.map! { |fn| fn = File.join(tracedir, fn) }

            vp_ip = ASMapper.get_ip_from_url vp
            vp_asn = ASMapper.query_asn vp_ip

            reader = YahooTRFileReader.new filelist
            firsthop = nil
            reader.each do |tr|
                # fill in the missing first hop skipped by traceroute
                if firsthop.nil?
                    firsthop = tr.hops[0] if tr.hops[0][2] != 0
                elsif tr.hops[0][2] == 0
                    tr.hops[0] = firsthop
                end
                tr.src = vp_ip
                tr.src_asn = vp_asn
                stats.add_yahoo tr
            end
        end
    
        # start to snapshot the result
        puts "[#{Time.now}] Start to snapshot the results for #{numday} days"
        output_date = "#{startdate.strftime("%Y%m%d")}_#{numday}d"

        fn = File.join(TopoConfig::YAHOO_OUTPUT_DIR, "AS#{output_date}.txt")
        stats.output_as fn
        puts "Output to #{fn}"

        fn = File.join(TopoConfig::YAHOO_OUTPUT_DIR, "ASLink#{output_date}.txt") 
        stats.output_aslinks fn
        puts "Output to #{fn}"

        fn = File.join(TopoConfig::YAHOO_OUTPUT_DIR, "ASBFS#{output_date}.txt")
        stats.output_as_bfs fn
        puts "Output to #{fn}"
    end

    #puts "#IP: #{stats.ip.size}"
    #puts "#IP_no_asn: #{stats.ip_no_asn.size}"
    
    puts "[#{Time.now}] Program ends"
end
