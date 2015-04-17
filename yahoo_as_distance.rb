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

    vp_stats = {}
    vp_info = {}

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1

        output_date = "#{startdate.strftime("%Y%m%d")}_#{numday}d"
        dist_fn = File.join(YAHOO_OUTPUT_DIR, "as_distance_#{output_date}.txt")
        File.delete(dist_fn) if File.exist?(dist_fn)

        links_fn = File.join(YAHOO_OUTPUT_DIR, "as_links_#{output_date}.txt")

        tracelist = retrieve_yahoo(date)
        puts "[#{Time.now}] Start the analysis on #{date}"

        tracelist.each do |vp, filelist|
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

            puts "[#{Time.now}] Processing data from #{vp}"
            vp_stats[vp] = ASAnalysis.new(yahoo_aslist) if not vp_stats.has_key?(vp)
            stats = vp_stats[vp]

            filelist = download_yahoo_data(filelist)
            reader = YahooTRFileReader.new filelist
            firsthop = nil

            reader.each do |tr|
                # fill in the missing first hop skipped by traceroute
                firsthop = tr.hops[0] if firsthop.nil? and tr.hops[0][2] != 0
                tr.hops[0] = firsthop if not firsthop.nil? and tr.hops[0][2] == 0

                tr.src_ip = vp_ip
                tr.src_asn = vp_asn
                stats.count_as(tr)
            end

            # start to output AS distance
            File.open(dist_fn, 'a') do |f|
                f.puts "VP: #{vp}"
            end
            stats.output_as_distance(dist_fn, true)
        end
        puts "Output to #{dist_fn}"

        # merge vp AS stats into overall stats
        overall_stats = ASAnalysis.new(yahoo_aslist)
        vp_stats.each { |vp, stats| overall_stats.merge(stats) }
        overall_stats.output_aslinks(links_fn)
        puts "Output to #{links_fn}"
    end

    puts "[#{Time.now}] Program ends"
end
