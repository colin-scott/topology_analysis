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

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        numday += 1

        tracelist = retrieve_yahoo(date)
        tracedir = TopoConfig::YAHOO_DATA_DIR

        puts "[#{Time.now}] Start the analysis on #{date}"
        hop_latency = [{}, {}, {}, {}, {}]
        vp_url = nil
        tracelist.each do |vp, filelist|
            puts "[#{Time.now}] Processing data from #{vp}"
            vp_url = vp

            filelist.each do |fn|
                localfn = File.join(tracedir, fn)
                localfn_ = localfn.gsub(".gz", "")
                next if File.exist? localfn or File.exist? localfn_
                remote_uri = TopoConfig::YAHOO_DATA_URI + fn
                puts "[#{Time.now}] Downloading #{fn}"
                `scp #{remote_uri} #{tracedir}`
            end
            filelist.map! { |fn| fn = File.join(tracedir, fn) }

            reader = YahooTRFileReader.new filelist
            # record only first 5 hop latency
            reader.each do |tr|
                tr.hops.each_with_index do |row, i|
                    break if i > 4
                    ip, lat, ttl, _ = row
                    iplatency = hop_latency[i]
                    if ttl != 0
                        iplatency[ip] = [] if not iplatency.has_key? ip
                        iplatency[ip] << lat
                    end
                end
            end
            # for now only test on one vp
            break
        end

        # start to snapshot the result
        puts "[#{Time.now}] Start to snapshot the results for #{numday} days"
        outprefix = "#{vp_url}_#{startdate.strftime("%Y%m%d")}_#{numday}d"

        fn = File.join(TopoConfig::YAHOO_OUTPUT_DIR, "#{outprefix}.txt")
        File.open(fn, 'w') do |f|
            hop_latency.each_with_index do |ip_latency, i|
                f.puts "=============== Hop #{i} ================"
                f.puts "IP\tcount\tmean\tstd"
                ip_latency.each do |ip, lats|
                    mean, std = get_mean_std lats
                    f.puts "#{ip}\t#{lats.size}\t#{mean}\t#{std}"
                end
            end
        end
        puts "Output to #{fn}"
    end

    #puts "#IP: #{stats.ip.size}"
    #puts "#IP_no_asn: #{stats.ip_no_asn.size}"
    
    puts "[#{Time.now}] Program ends"
end
