require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'
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
    #elsif options[:duration].nil?
    #    put "No duration is given."
    #    exit
    end

    startdate = options[:start]
    #duration = options[:duration]
    yahoo_aslist = load_yahoo_aslist

    vp_info = {}
    #numday = 0

    #while numday < duration
        #date = (startdate + numday).strftime("%Y%m%d")
        #numday += 1
        date = startdate.strftime("%Y%m%d")
        nextdate = (startdate+1).strftime("%Y%m%d")

        churn_fn = File.join(YAHOO_OUTPUT_DIR, "traceroute_churn_#{date}.txt")
        File.delete(churn_fn) if File.exist?(churn_fn)
        #ashops_fn = File.join(IPLANE_OUTPUT_DIR, "traceroute_ashops_#{date}.txt")
        #File.delete(ashops_fn) if File.exist?(ashops_fn)

        tracelist_base = retrieve_yahoo(date)
        tracelist_comp = retrieve_yahoo(nextdate)

        tracelist_base.each do |vp, filelist|
            if not tracelist_comp.has_key?(vp)
                puts "#{vp} has no data on #{nextdate}"
                next
            end

            puts "[#{Time.now}] Processing data from #{vp} on #{date}"
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

            filelist = download_yahoo_data(filelist)
            reader = YahooTRFileReader.new(filelist)
            stats = ASAnalysis.new(yahoo_aslist)
            firsthop = nil
            tr_total= 0

            reader.each do |tr|
                tr_total += 1
                firsthop = tr.hops[0] if firsthop.nil? and tr.hops[0][2] != 0
                tr.hops[0] = firsthop if not firsthop.nil? and tr.hops[0][2] == 0

                tr.src_ip = vp_ip
                tr.src_asn = vp_asn
                stats.churn_collect(tr)
            end
            reached = 0
            stats.tr_dist.each { |_, cnt| reached += cnt }

            # start to output
            File.open(churn_fn, 'a') do |f|
                f.puts "VP: #{vp}"
                f.puts "#traceroute on #{date}: #{tr_total}"
                f.puts "#reached tr on #{date}: #{reached}"
            end

            # compare next day's result
            puts "[#{Time.now}] Comparing data from #{nextdate}"

            filelist = download_yahoo_data(tracelist_comp[vp])
            reader = YahooTRFileReader.new(filelist)
            tr_total = 0
            reached = 0
            new_tr = 0
            new_as_path = 0

            reader.each do |tr|
                tr_total+= 1
                firsthop = tr.hops[0] if firsthop.nil? and tr.hops[0][2] != 0
                tr.hops[0] = firsthop if not firsthop.nil? and tr.hops[0][2] == 0

                tr.src_ip = vp_ip
                tr.src_asn = vp_asn
                ret = stats.churn_compare(tr)
                
                reached += 1 if ret != 0
                if ret == 1
                    new_tr += 1
                elsif ret == 2
                    new_as_path += 1
                end
            end

            File.open(churn_fn, 'a') do |f|
                f.puts "#traceroute on #{nextdate}: #{tr_total}"
                f.puts "#reached tr on #{nextdate}: #{reached}"
                f.puts "#new traceroute: #{new_tr}"
                f.puts "#new AS paths: #{new_as_path}"
            end
        end
        puts "Output to #{churn_fn}"

    puts "[#{Time.now}] Program ends"
end
