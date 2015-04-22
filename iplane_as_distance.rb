require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/astrace.rb'
require_relative 'lib/analysis.rb'

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
    vp_info = load_iplane_vp_info
    vp_stats = {}
    selected_as = nil

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1

        output_date = "#{startdate.strftime("%Y%m%d")}_#{numday}d"
        as_fn = File.join(IPLANE_OUTPUT_DIR, "as_#{output_date}.txt")
        dist_fn = File.join(IPLANE_OUTPUT_DIR, "as_distance_#{output_date}.txt")
        File.delete(dist_fn) if File.exist?(dist_fn)
        links_fn = File.join(IPLANE_OUTPUT_DIR, "as_links_#{output_date}.txt")
        ashops_fn = File.join(IPLANE_OUTPUT_DIR, "traceroute_hops_#{output_date}.txt")
        File.delete(ashops_fn) if File.exist?(ashops_fn)

        tracelist = retrieve_iplane(date)
        selected_vps, selected_as = select_iplane_vps(tracelist.keys, selected_as)
        puts "[#{Time.now}] Start the analysis on #{date} from #{selected_vps.size} nodes"

        selected_vps.each do |vp|
            uris = tracelist[vp]
            vp_ip, vp_asn = vp_info[vp]

            puts "[#{Time.now}] Processing data from #{vp}"
            vp_stats[vp_asn] = [vp, ASAnalysis.new] if not vp_stats.has_key?(vp_asn)
            _, stats = vp_stats[vp_asn]
            vp_stats[vp_asn][0] = vp # update the vp url

            astrace_file = get_iplane_astrace_file(date, uris)
            reader = ASTraceReader.new(astrace_file)
            reader.each do |astrace|
                astrace.src_asn = vp_asn
                stats.count(astrace)
            end
        end
        # merge vp AS stats into overall stats
        overall_stats = ASAnalysis.new
        vp_stats.each do |asn, val| 
            vp, stats = val
            # output AS distance
            File.open(dist_fn, 'a') do |f|
                f.puts "VP: #{vp}"
                f.puts "ASN: #{asn}"
            end
            stats.output_as_distance(dist_fn, true)
            # output traceroute AS distance
            File.open(ashops_fn, 'a') do |f|
                f.puts "VP: #{vp}"
                f.puts "ASN: #{asn}"
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
        overall_stats.output_aslinks(links_fn)
        puts "Output to #{links_fn}"
    end

    puts "[#{Time.now}] Program ends"
end
