require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'lib/analysis.rb'

include TopoConfig

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
    targets = load_target_list

    overall_stats = ASAnalysis.new
    vp_info = {}
    numday = 0

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1

        fn = File.join(IPLANE_OUTPUT_DIR, "traceroute_as_hops_#{date}.txt")
        File.delete(fn) if File.exist?(fn)

        tracedir = File.join(IPLANE_DATA_DIR, date)
        Dir.mkdir(tracedir) if not Dir.exist? tracedir
        tracelist = retrieve_iplane(date)

        puts "[#{Time.now}] Start the analysis on #{date}"
        tracelist.each do |vp, uris|
            if IPLANE_BLACKLIST.include?(vp)
                puts "Skip the broken node #{vp}"
                next
            end

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

            stats = ASAnalysis.new
            reader = IPlaneTRFileReader.new(index_file, trace_file)
            firsthop = nil
            reader.each do |tr|
                next if not targets.include?(tr.dst)
                next if tr.hops.size == 0

                firsthop = tr.hops[0] if firsthop.nil? and tr.hops[0][2] != 0
                tr.hops[0] = firsthop if not firsthop.nil? and tr.hops[0][2] == 0

                tr.src_ip = vp_ip
                tr.src_asn = vp_asn
                stats.count_as_hops_iplane(tr)
            end
            File.open(fn, 'a') { |f| f.puts "VP: #{vp}" }
            stats.output_tr_distance(fn)
        end
        puts "Output to #{fn}"
    end
    puts "[#{Time.now}] Program ends"
end
