require 'set'

require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'lib/asmapper.rb'

class Stats
  
    attr_reader :count

    def initialize 
        @iterations = {}
        load_iteration
        # following vars store stats results
        # need to clear when start a new batch
        @ip_hops = {}
        @as_hops = {}
        @ip_list = Set.new
        @peer_as = Set.new
        @filepfx = nil
        @vp = nil
    end

    def load_iteration
        # load iteration records
        fn = TopoConfig::ITERATION_FILE
        firstline = true
        File.open(fn).each_line do |line|
            if firstline
                firstline = false
                next
            end
            idx, vp, date, starttime, endtime, duration, valid, invalid, filelist = line.split(',')
            files = filelist.split('|')
            @iterations[idx.to_i] = [vp, files]
        end
    end

    def clear
        @ip_hops.clear
        @as_hops.clear
        @ip_list.clear
        @peer_as.clear
        @filepfx = nil
        @vp = nil
    end

    def analyze targets
        @filepfx = "iter#{targets.gsub(',', '_')}"
        # parse targets into range
        iterlist = parse_targets targets
        # start the analysis
        iterlist.each { |iterid| analyze_iteration(iterid) }
        # write results to file
        write_summary iterlist.size
        write_cdf("#{@filepfx}.iphop.csv", @ip_hops)
        write_cdf("#{@filepfx}.ashop.csv", @as_hops)
        write_peeras
        # clear results
        clear
    end

    def parse_targets targets
        iterlist = []
        if targets.include? ','
            targets.split(',').each { |t| iterlist += parse_targets(t) }
        elsif targets.include? '-'
            st, ed = targets.split('-')
            iterlist = (st.to_i .. ed.to_i).to_a
        else
            iterlist = [targets.to_i]
        end
        iterlist
    end

    def analyze_iteration iterid
        puts "[#{Time.now}] Parse iteration #{iterid}"
        vp, files = @iterations[iterid]
        if @vp.nil?
            vp_asn = get_vp_asn vp
            @vp = [vp, vp_asn]
        elsif @vp[0] != vp
            raise "Aggregation analysis only works data from same VP"
        end
        puts "[#{Time.now}] VP:#{vp} ASN:#{vp_asn}"
        files.each do |file|
            items = file.split(':')
            fn = items[0]
            st_line = items[1].to_i
            ed_line = (items.size > 2) ? items[2].to_i : nil
            puts "[#{Time.now}] #{fn} #{st_line}-#{ed_line}"
            reader = AsciiTracerouteFileReader.new fn
            reader.seek st_line
            while true
                tr = reader.next_traceroute
                break if tr.nil?
                next if not tr.valid?
                pass tr, vp_asn
                break if not ed_line.nil? and reader.lineno >= ed_line
            end
        end
    end

    def write_summary niter
        fn = File.join(TopoConfig::OUTPUT_DIR, "#{@filepfx}.summary.txt")
        puts "[#{Time.now}] Write summary to #{fn}"
        file = File.open(fn, 'w')
        file.puts("Vantage Point: #{@vp[0]}")
        file.puts("VP ASN: #{@vp[1]}")
        file.puts("#iterations: #{niter}")
        file.puts("#IP: #{@ip_list.size}")

        avg_ip_hops = 0
        cnt = 0
        @ip_hops.each { |hop, c| avg_ip_hops += hop * c; cnt += c }
        file.puts("Average IP hops: #{avg_ip_hops.to_f / cnt}")
        
        avg_as_hops = 0
        cnt = 0
        @as_hops.each { |hop, c| avg_as_hops += hop * c; cnt += c }
        file.puts("Average AS hops: #{avg_as_hops.to_f / cnt}")
        
        file.puts("#traceroute: #{cnt}")
        file.puts("#PeerAS: #{@peer_as.size}")
        file.close
    end

    def write_cdf fn, hops
        fn = File.join(TopoConfig::OUTPUT_DIR, fn)
        puts "[#{Time.now}] Write to CDF file #{fn}"
        File.open(fn, 'w') do |file|
            hops.keys.sort.each { |n| file.puts "#{n},#{hops[n]}" }
        end
    end

    def write_peeras 
        fn = File.join(TopoConfig::OUTPUT_DIR, "#{@filepfx}.peeras.txt")
        puts "[#{Time.now}] Write to PeerAS file #{fn}"
        File.open(fn, 'w') do |file|
            @peer_as.sort.each { |asn| file.puts asn }
        end
    end
    
    def log_abnormal tr, aslist
        fn = File.join(TopoConfig::OUTPUT_DIR, "#{@filepfx}.abnormal.txt")
        File.open(fn, 'a') do |file|
            file.puts '---------------------------------------'
            file.puts tr.to_s
            file.puts "AS hops: #{aslist.size}"
            file.puts aslist.join(',')
        end
    end

    def get_vp_asn vp
        result = `nslookup #{vp}`.split.compact[-1]
        ip = result.split(':')[-1].strip
        ASMapper.query_as_num ip
    end

    def pass tr, vp_asn
        if @ip_hops.has_key? tr.nhop
            @ip_hops[tr.nhop] += 1
        else
            @ip_hops[tr.nhop] = 1
        end
        # since some of traceroutes doesn't have first hop
        # let's skip 1st as hop for all, and start counter from 1
        ashops = 1
        peerasn = nil
        aslist = [vp_asn]
        tr.hops.each do |ip,_,ttl,_|
            next if ttl == 0
            @ip_list << ip
            asn = ASMapper.query_as_num ip
            next if asn.nil?
            # skip the AS hop within vp's AS
            next if asn == vp_asn
            peerasn = asn if peerasn.nil?
            if asn != aslist[-1]
                ashops += 1
                aslist << asn
            end
        end
        log_abnormal(tr, aslist) if ashops > 8
        if @as_hops.has_key? ashops
            @as_hops[ashops] += 1
        else
            @as_hops[ashops] = 1
        end
        @peer_as << peerasn if not peerasn.nil?
    end
end

if $0 == __FILE__
    if ARGV.size == 0
        puts "Usage: #{File.basename($0)} <iteration> [<iteration>...]"
        puts "    <iteration>\t\tsingle iteration id, e.g., 1"
        puts "\t\t\titeration range, e.g., \"2-3\", \"4-7,9-10\" (for aggregation analysis)"
        exit
    end
    stats = Stats.new
    while not ARGV.empty?
        targets = ARGV.shift
        stats.analyze targets
    end
end
