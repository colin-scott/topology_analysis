require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/astrace.rb'
require_relative 'lib/analysis.rb'

include TopoConfig

module ChurnAnalysis
def self.analyze(options)
    startdate = options[:start]
    duration = if options[:duration].nil? then 1 else options[:duration] end

    vp_info = load_yahoo_vp_info
    numday = 0

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        nextdate = (startdate + numday + 1).strftime("%Y%m%d")
        numday += 1

        churn_fn = File.join(YAHOO_OUTPUT_DIR, "traceroute_churn_#{date}.txt")
        File.delete(churn_fn) if File.exist?(churn_fn)

        tracelist_base = retrieve_yahoo(date)
        tracelist_comp = retrieve_yahoo(nextdate)
        selected_vps = select_yahoo_vps(tracelist_base.keys)

        selected_vps.each do |vp|
            vp_ip, vp_asn = vp_info[vp]
            if not tracelist_comp.has_key?(vp)
                puts "#{vp} has no data on #{nextdate}"
                next
            end

            puts "[#{Time.now}] Processing data from #{vp} on #{date}"

            stats = ASAnalysis.new
            astrace_filelist = get_yahoo_astrace_filelist(tracelist_base[vp])
            reader = ASTraceReader.new(astrace_filelist)
            reader.each do |astrace|
                astrace.src_ip = vp_ip
                astrace.src_asn = vp_asn
                stats.churn_collect(astrace)
            end

            # start to output
            File.open(churn_fn, 'a') do |f|
                f.puts "VP ASN: #{vp_asn}"
                f.puts "VP on #{date}: #{vp}"
                f.puts "reached traceroute on #{date}: #{stats.reached}"
            end

            # compare next day's result
            puts "[#{Time.now}] Comparing data from #{vp} on #{nextdate}"

            astrace_filelist = get_yahoo_astrace_filelist(tracelist_comp[vp])
            reader = ASTraceReader.new(astrace_filelist)
            reached = 0
            new_tr = 0
            new_as_path = 0

            reader.each do |astrace|
                astrace.src_ip = vp_ip
                astrace.src_asn = vp_asn
                ret = stats.churn_compare(astrace)
                
                reached += 1 if ret != 0
                if ret == 1
                    new_tr += 1
                elsif ret == 2
                    new_as_path += 1
                end
            end

            File.open(churn_fn, 'a') do |f|
                f.puts "VP on #{nextdate}: #{vp}"
                f.puts "reached traceroute on #{nextdate}: #{reached}"
                f.puts "new traceroute: #{new_tr}"
                f.puts "new AS paths: #{new_as_path}"
                f.puts "--------------------------------------------"
            end
        end
        puts "Output to #{churn_fn}"
    end
    puts "[#{Time.now}] Program ends"
end
end
