require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'lib/analysis'

# return [mean, std]
def get_mean_std arr
    mean = arr.inject(0) { |sum, x| sum + x } / arr.size
    diff = arr.inject(0) { |sum, x| sum + (x - mean) ** 2 } / arr.size
    std = Math.sqrt(diff)
    return [mean, std]
end

class LatencyInfo
    attr_reader :latency, :prev_ip, :mean, :std, :std_sub
    def initialize
        @latency = {}
        @prev_ip = {}
        @mean = {}
        @std = {}
        @std_sub = {}
    end

    def record_size ip
        return @latency[ip].size
    end

    def insert ip, prev, lat
        @latency[ip] = [] if not @latency.has_key? ip
        @prev_ip[ip] = {} if not @prev_ip.has_key? ip
        @latency[ip] << lat
        if not prev.nil?
            if @prev_ip[ip].has_key? prev
                @prev_ip[ip][prev] += 1
            else
                @prev_ip[ip][prev] = 1
            end
        end
    end

    def generate_mean_std
        @latency.each do |ip, lats| 
            next if lats.size < 100
            mean, std = get_mean_std lats
            @mean[ip] = mean
            @std[ip] = std
        end
    end

    def subtract_prevhop prev_lat_info
        @std.each do |ip, std|
            total = @latency[ip].size
            @prev_ip[ip].each do |prev, cnt|
                if prev_lat_info.std.has_key? prev
                    std -= (prev_lat_info.std[prev] * cnt / prev_lat_info.record_size(prev))
                end
            end
            @std_sub[ip] = std
        end
    end
end

if $0 == __FILE__
    options = {}
    optparse = OptionParser.new do |opts|
        options[:start] = nil
        opts.on("-s", "--start DATE", "Specify the start date (format: 20150101)") do |start|
            options[:start] = Date.parse(start)
        end
=begin
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
=end
        opts.on("-h", "--help", "Prints this help") do 
            puts opts
            exit
        end
    end
    optparse.parse!
    if options[:start].nil?
        puts "No start date is given."
        exit
    #elsif options[:duration].nil?
    #    put "No duration is given."
    #    exit
    end

    startdate = options[:start]
    #duration = options[:duration]
    #puts "Duration: #{duration} days"

    #numday = 0

    #while numday < duration
        date = (startdate).strftime("%Y%m%d")
        #numday += 1

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

            
            info_per_hop = {
                0 => LatencyInfo.new,
                1 => LatencyInfo.new,
                2 => LatencyInfo.new,
                3 => LatencyInfo.new,
                4 => LatencyInfo.new,
            }

            reader = YahooTRFileReader.new filelist
            # record only first 5 hop latency
            reader.each do |tr|
                lastip = nil
                tr.hops.each_with_index do |row, i|
                    break if i > 4
                    ip, lat, ttl, _ = row
                    if ttl != 0
                        latinfo = info_per_hop[i]
                        latinfo.insert(ip, lastip, lat)
                    else
                        ip = nil
                    end
                    lastip = ip
                end
            end
            
            info_per_hop.each do |hop, latinfo|
                latinfo.generate_mean_std
                latinfo.subtract_prevhop(info_per_hop[hop-1]) if hop > 1
            end

            # start to snapshot the result
            puts "[#{Time.now}] Start to snapshot the results"
            outprefix = "#{vp}_#{startdate.strftime("%Y%m%d")}"

            fn = File.join(TopoConfig::YAHOO_OUTPUT_DIR, "#{outprefix}.txt")
            File.open(fn, 'w') do |f|
                info_per_hop.each do |hop, latinfo|
                    f.puts "=============== Hop #{hop+1} ================"
                    if hop <= 1
                        f.puts "IP\tcount\tmean\tstd"
                        latinfo.mean.each do |ip, mean|
                            cnt = latinfo.record_size(ip)
                            std = latinfo.std[ip]
                            f.puts "#{ip}\t#{cnt}\t#{mean}\t#{std}"
                        end
                    else
                        f.puts "IP\tcount\tmean\tstd\tstd subtract"
                        latinfo.mean.each do |ip, mean|
                            cnt = latinfo.record_size(ip)
                            std = latinfo.std[ip]
                            std_sub = latinfo.std_sub[ip]
                            f.puts "#{ip}\t#{cnt}\t#{mean}\t#{std}\t#{std_sub}"
                            latinfo.prev_ip[ip].each do |prev, n|
                                f.printf("# %s %d\n", prev, n)
                            end
                        end
                    end
                end
            end
            puts "Output to #{fn}"
            break 
        end
        #break
    #end

    #puts "#IP: #{stats.ip.size}"
    #puts "#IP_no_asn: #{stats.ip_no_asn.size}"
    
    puts "[#{Time.now}] Program ends"
end
