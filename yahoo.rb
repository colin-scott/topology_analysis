require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'lib/analysis'

include TopoConfig

if $0 == __FILE__
    options = {}
    optparse = OptionParser.new do |opts|
        options[:start] = nil
        opts.on("-s", "--start DATE", "Specify the start date (format: 20150101)") do |start|
            options[:start] = Date.parse(start)
        end
        options[:duration] = nil
        opts.on("-d", "--duration DURATION", "Sepcify the duration of days/weeks (format: 1d, 5d, 1w)") do |duration|
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

    overall_stats = ASAnalysis.new(yahoo_aslist)
    vp_stats = {}
    vp_info = {}

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1

        tracelist = retrieve_yahoo(date)
        puts "[#{Time.now}] Start the analysis on #{date}"

        tracelist.each do |vp, filelist|
            vp_stats[vp] = ASAnalysis.new(yahoo_aslist) if not vp_stats.has_key?(vp)
            stats = vp_stats[vp]

            puts "[#{Time.now}] Processing data from #{vp}"

            filelist = download_yahoo_data(filelist)

            if vp_info.has_key?(vp)
                vp_ip, vp_asn = vp_info[vp]
            else
                vp_ip = ASMapper.get_ip_from_url(vp)
                vp_asn = ASMapper.query_asn(vp_ip)
                vp_info[vp] = [vp_ip, vp_asn]
            end

            if vp_asn.nil?
                puts "#{vp}, #{vp_ip}"
            end

            reader = YahooTRFileReader.new filelist
            firsthop = nil
            reader.each do |tr|
                # fill in the missing first hop skipped by traceroute
                if firsthop.nil?
                    firsthop = tr.hops[0] if tr.hops[0][2] != 0
                elsif tr.hops[0][2] == 0
                    tr.hops[0] = firsthop
                end
                tr.src_ip = vp_ip
                tr.src_asn = vp_asn
                stats.add_yahoo(tr)
            end
            # merge vp AS stats into overall stats
            overall_stats.merge(stats)
        end
    
        # start to snapshot the result
        puts "[#{Time.now}] Start to snapshot the results for #{numday} days"
        output_date = "#{startdate.strftime("%Y%m%d")}_#{numday}d"

        fn = File.join(YAHOO_OUTPUT_DIR, "AS_#{output_date}.txt")
        overall_stats.output_as(fn)
        puts "Output to #{fn}"

        fn = File.join(YAHOO_OUTPUT_DIR, "AS_Links_#{output_date}.txt") 
        overall_stats.output_aslinks(fn)
        puts "Output to #{fn}"

        fn = File.join(YAHOO_OUTPUT_DIR, "AS_Distance_#{output_date}.txt")
        File.delete(fn) if File.exist?(fn)
        overall_stats.output_as_distance(fn)
        puts "Output to #{fn}"

        fn = File.join(YAHOO_OUTPUT_DIR, "AS_VP_Distance_#{output_date}.txt")
        File.delete(fn) if File.exist?(fn)
        vp_stats.keys.sort.each do |vp|
            stats = vp_stats[vp]
            File.open(fn, 'a') { |f| f.puts("VP: #{vp} (#{vp_info[vp][0]}, AS#{vp_info[vp][1]})") }
            stats.output_as_distance(fn, true)
        end
        puts "Output to #{fn}"
    end

    puts "[#{Time.now}] Program ends"
end
