require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/asmapper.rb'
require_relative 'lib/traceroute_reader_util.rb'

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

    vp_info = {}
    numday = 0

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1

        fn = File.join(IPLANE_OUTPUT_DIR, "Firsthop_#{date}.txt")
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

            reader = IPlaneTRFileReader.new(index_file, trace_file)
            tr_total = 0
            reached = 0
            first_hop_ip = Set.new
            first_hop_as = Set.new
            first_hop_missing = 0
            reader.each do |tr|
                next if not targets.include?(tr.dst)
                next if tr.hops.size == 0
                tr_total += 1
                first_hop = tr.hops[0]
                if first_hop[2] == 0
                    # missing hop
                    first_hop_missing += 1
                else
                    first_hop_ip << first_hop[0]
                end
                reached += 1 if tr.hops[-1][0] == tr.dst
            end
            first_hop_ip.each { |ip| first_hop_as << ASMapper.query_asn(ip) }
            File.open(fn, 'a') do |f|
                f.puts "VP: #{vp}"
                f.puts "Total traceroute: #{tr_total}"
                f.puts "Reached: #{reached}"
                f.puts "First hop missing: #{first_hop_missing}"
                f.puts "First hop IP: #{first_hop_ip.size}"
                f.puts "First hop AS: #{first_hop_as.size}"
                first_hop_ip.sort.each { |ip| f.puts "#{ip} (#{ASMapper.query_asn(ip)})" }
            end
        end
        puts "Output to #{fn}"
    end
    puts "[#{Time.now}] Program ends"
end
