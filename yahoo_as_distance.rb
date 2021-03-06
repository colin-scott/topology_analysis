require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/astrace.rb'
require_relative 'lib/analysis.rb'

include TopoConfig

module ASDistance
def self.analyze(options)
    if options[:duration].nil?
        puts "No duration is given."
        exit
    end

    startdate = options[:start]
    duration = options[:duration]
    puts "Duration: #{duration} days"

    numday = 0
    vp_info = load_yahoo_vp_info
    yahoo_aslist = load_yahoo_aslist
    vp_stats = {}

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1

        output_date = "#{startdate.strftime("%Y%m%d")}_#{numday}d"
        as_fn = File.join(YAHOO_OUTPUT_DIR, "as_#{output_date}.txt")
        dist_fn = File.join(YAHOO_OUTPUT_DIR, "as_distance_#{output_date}.txt")
        File.delete(dist_fn) if File.exist?(dist_fn)
        links_fn = File.join(YAHOO_OUTPUT_DIR, "as_links_#{output_date}.txt")
        ashops_fn = File.join(YAHOO_OUTPUT_DIR, "traceroute_hops_#{output_date}.txt")
        File.delete(ashops_fn) if File.exist?(ashops_fn)

        tracelist = retrieve_yahoo(date)
        selected_vps = select_yahoo_vps(tracelist.keys)
        puts "[#{Time.now}] Start the analysis on #{date} from #{selected_vps.size} nodes"
        #next

        selected_vps.each do |vp|
            filelist = tracelist[vp]
            vp_ip, vp_asn = vp_info[vp]

            puts "[#{Time.now}] Processing data from #{vp}"
            vp_stats[vp] = ASAnalysis.new(yahoo_aslist) if not vp_stats.has_key?(vp)
            stats = vp_stats[vp]

            astrace_filelist = get_yahoo_astrace_filelist(filelist, vp_ip)
            reader = ASTraceReader.new(astrace_filelist)
            reader.each do |astrace|
                astrace.src_asn = vp_asn
                stats.count(astrace)
            end
        end
        
        # merge vp AS stats into overall stats
        overall_stats = ASAnalysis.new(yahoo_aslist)
        vp_stats.each do |vp, stats| 
            vp_asn = vp_info[vp][1]
            # output AS distance
            File.open(dist_fn, 'a') do |f|
                f.puts "VP: #{vp}"
                f.puts "ASN: #{vp_asn}"
            end
            stats.output_as_distance(dist_fn, true)
            # output traceroute AS distance
            File.open(ashops_fn, 'a') do |f|
                f.puts "VP: #{vp}"
                f.puts "ASN: #{vp_asn}"
                f.puts "Total traceroute: #{stats.tr_total}"
                f.puts "Total reached traceroute: #{stats.reached}"
            end
            stats.output_tr_hops(ashops_fn)

            overall_stats.merge(stats)
        end
        puts "Output to #{dist_fn}"
        puts "Output to #{ashops_fn}"

        overall_stats.output_as(as_fn)
        puts "Output to #{as_fn}"
        #overall_stats.output_aslinks(links_fn)
        #puts "Output to #{links_fn}"
    end

    puts "[#{Time.now}] Program ends"
end
end
