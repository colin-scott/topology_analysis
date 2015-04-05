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
    
    numday = 0
    stats = Analysis.new 

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1

        tracelist = retrieve_iplane(date)
        tracedir = File.join(TopoConfig::IPLANE_DATA_DIR, date)
        Dir.mkdir(tracedir) if not Dir.exist? tracedir

        targets = load_target_list

        puts "[#{Time.now}] Start the analysis on #{date}"
        tracelist.each do |vp, uris|
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
            vp_ip = ASMapper.get_ip_from_url vp_url
            vp_asn = ASMapper.query_asn vp_ip
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
            #break
        end
    end

    as_bfs = {}
    output_date = "#{startdate.strftime("%Y%m%d")}_#{duration}d"

    puts "[#{Time.now}] Start to output the results"
    puts "Duration: #{duration} days"
    puts "#IP: #{stats.ip.size}"
    puts "#IP_no_asn: #{stats.ip_no_asn.size}"
    fn = File.join(TopoConfig::IPLANE_OUTPUT_DIR, "AS#{output_date}.txt")
    File.open(fn, 'w') do |f|
        stats.as.each do |asn, nhop| 
            f.puts asn
            as_bfs[nhop] = Set.new if not as_bfs.has_key? nhop
            as_bfs[nhop] << asn
        end
    end

    puts "Output to #{fn}"
    fn = File.join(TopoConfig::IPLANE_OUTPUT_DIR, "ASLink#{output_date}.txt")
    File.open(fn, 'w') do |f|
        stats.as_links.each { |a,b| f.puts "#{a} #{b}" }
    end
    puts "Output to #{fn}"

    fn = File.join(TopoConfig::IPLANE_OUTPUT_DIR, "ASBFS#{output_date}.txt")
    File.open(fn, 'w') do |f|
        as_bfs.keys.sort.each do |nhop|
            asnlist = as_bfs[nhop]
            f.printf("%2d: %d\n", nhop, asnlist.size)
        end
        as_bfs.keys.sort.each do |nhop|
            asnlist = as_bfs[nhop]
            f.puts "--------------------- #{nhop} -----------------------"
            asnlist.each { |asn| f.puts asn }
        end
    end
    puts "Output to #{fn}"
        
    puts "[#{Time.now}] Program ends"
end
