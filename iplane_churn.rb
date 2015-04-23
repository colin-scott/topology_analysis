require 'set'

require_relative 'retrieve_data.rb'
require_relative 'config.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'lib/analysis.rb'

include TopoConfig

module ChurnAnalysis
def self.analyze(options)
    startdate = options[:start]
    duration = options[:duration]
    selected_as = options[:aslist]
    targets = load_target_list

    vp_info = load_iplane_vp_info
    numday = 0
    vp_stats = {}

    while numday < duration
        date = (startdate + numday).strftime("%Y%m%d")
        nextdate = (startdate + numday + 1).strftime("%Y%m%d")
        numday += 1

        churn_fn = File.join(IPLANE_OUTPUT_DIR, "traceroute_churn_#{date}.txt")
        File.delete(churn_fn) if File.exist?(churn_fn)

        tracelist_base = retrieve_iplane(date)
        tracelist_comp = retrieve_iplane(nextdate)
        base_vps, selected_as = select_iplane_vps(tracelist_base.keys, selected_as)
        comp_vps, selected_as = select_iplane_vps(tracelist_comp.keys, selected_as)
        comp_vp_lut = {}
        comp_vps.each { |vp| comp_vp_lut[vp_info[vp][1]] = vp }

        base_vps.each do |vp|
            vp_ip, vp_asn = vp_info[vp]
            if not comp_vp_lut.has_key?(vp_asn)
                puts "#{vp} (#{vp_asn}) has no data on #{nextdate}"
                next
            end

            puts "[#{Time.now}] Processing data from #{vp} on #{date}"
            astrace_file = get_iplane_astrace_file(date, tracelist_base[vp])
            
            stats = ASAnalysis.new
            reader = ASTraceReader.new(astrace_file)
            reader.each do |astrace|
                astrace.src_ip = vp_ip
                astrace.src_asn = vp_asn
                stats.churn_collect(astrace)
            end

            # start to output
            File.open(churn_fn, 'a') do |f|
                f.puts "VP ASN: #{vp_asn}"
                f.puts "VP on #{date}: #{vp}"
                f.puts "#reached traceroute on #{date}: #{stats.reached}"
            end

            # compare next day's result
            vp = comp_vp_lut[vp_asn]
            vp_ip, vp_asn = vp_info[vp]
            puts "[#{Time.now}] Comparing data from #{vp} on #{nextdate}"

            astrace_file = get_iplane_astrace_file(nextdate, tracelist_comp[vp])
            reader = ASTraceReader.new(astrace_file)
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
