require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'lib/analysis'

def load_target_list
    targets = Set.new
    File.open(TopoConfig::TARGET_LIST_FILE).each_line do |ip|
        targets << ip.chomp
    end
    targets
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
    vp_stats = {}
    vp_info = {}
    #stats = Analysis.new 
    targets = load_target_list

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1

        tracedir = File.join(TopoConfig::IPLANE_DATA_DIR, date)
        Dir.mkdir(tracedir) if not Dir.exist? tracedir
        tracelist = retrieve_iplane(date)

        puts "[#{Time.now}] Start the analysis on #{date}"
        tracelist.each do |vp, uris|
            vp_stats[vp] = Analysis.new if not vp_stats.has_key? vp
            stats = vp_stats[vp]

            puts "[#{Time.now}] Processing data from #{vp}"
            index_uri = uris['index']
            index_file = File.join(tracedir, index_uri[index_uri.rindex('/')+1..-1])
            if not File.exist? index_file
                puts "Download #{index_file}"
                `curl #{index_uri} -o #{index_file}`
            end

            trace_uri = uris['trace']
            trace_file = File.join(tracedir, trace_uri[trace_uri.rindex('/')+1..-1])
            trace_file_ = trace_file.gsub(".gz", "")
            if not File.exist? trace_file and not File.exist? trace_file_
                puts "Download #{trace_file}"
                `curl #{trace_uri} -o #{trace_file}`
            end

            vp_url = File.basename(index_file).gsub("index.out.", "")
            if vp_info.has_key? vp_url
                vp_ip, vp_asn = vp_info[vp_url]
            else
                vp_ip = ASMapper.get_ip_from_url vp_url
                vp_asn = ASMapper.query_asn vp_ip
                vp_info[vp_url] = [vp_ip, vp_asn]
            end
            
            if vp_asn.nil?
                puts "#{vp_url}, #{vp_ip}"
            end

            reader = IPlaneTRFileReader.new(index_file, trace_file)
            reader.each do |tr|
                if targets.include? tr.dst
                    tr.src = vp_ip
                    tr.src_asn = vp_asn
                    stats.add tr
                end
            end
            #puts stats.as.size
        end

        # start to snapshot the result
        puts "[#{Time.now}] Start to snapshot the results for #{numday} days"
        output_date = "#{startdate.strftime("%Y%m%d")}_#{numday}d"

        fn = File.join(TopoConfig::IPLANE_OUTPUT_DIR, "AS_VP_BFS#{output_date}.txt")
        vp_stats.keys.sort.each do |vp|
            stats = vp_stats[vp]
            File.open(fn, 'a') { |f| f.puts "VP: #{vp} (#{vp_info[vp][0]}, AS#{vp_info[vp][1]})" }
            stats.output_as_bfs fn
        end
        puts "Output to #{fn}"
=begin
        fn = File.join(TopoConfig::IPLANE_OUTPUT_DIR, "AS#{output_date}.txt")
        stats.output_as fn
        puts "Output to #{fn}"

        fn = File.join(TopoConfig::IPLANE_OUTPUT_DIR, "ASLink#{output_date}.txt") 
        stats.output_aslinks fn
        puts "Output to #{fn}"

        fn = File.join(TopoConfig::IPLANE_OUTPUT_DIR, "ASBFS#{output_date}.txt")
        stats.output_as_bfs fn
        puts "Output to #{fn}"
=end
    end

    #puts "#IP: #{stats.ip.size}"
    #puts "#IP_no_asn: #{stats.ip_no_asn.size}"
       
    puts "[#{Time.now}] Program ends"
end
