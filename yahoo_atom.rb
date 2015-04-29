require_relative 'config.rb'
require_relative 'retrieve_data.rb'
require_relative 'lib/traceroute_reader_util.rb'
require_relative 'lib/astrace.rb'
require_relative 'lib/atom.rb'

module BGPAtomAnalysis
def self.analyze(options)
    if options[:duration].nil?
        puts "No duration is given."
        exit
    end

    startdate = options[:start]
    duration = options[:duration]
    vp_info = load_yahoo_vp_info

    all_tracelist = {}
    puts "Duration: #{duration} days"

    (0...duration).each do |i|
        date = (startdate + i).strftime("%Y%m%d")
        all_tracelist[date] = retrieve_yahoo(date)
    end

    startdatestr = startdate.strftime("%Y%m%d")
    selected_vps = select_yahoo_vps(all_tracelist[startdatestr].keys)
    puts "[#{Time.now}] Selected #{selected_vps.size} VPs"

    selected_vps.each do |vp|
        _, vp_asn = vp_info[vp]
        atom_info_map = {}
        available_date = []
        puts "[#{Time.now}] Start for VP #{vp}"

        (0...duration).each do |i|
            date = (startdate + i).strftime("%Y%m%d")
            tracelist = all_tracelist[date]
            next if not tracelist.keys.include?(vp)

            puts "[#{Time.now}] Processing date #{date}"
            available_date << date
            filelist = tracelist[vp]

            localfilelist = download_yahoo_data(filelist)
            reader = YahooTRFileReader.new(localfilelist)
            reader.each do |tr|
                next if tr.dst != tr.hops[-1][0]
                atom_info_map[tr.dst] = BGPAtom.new(tr.dst) if not atom_info_map.has_key?(tr.dst)
                atom_info_map[tr.dst].add_traceroute(tr)
            end

            astrace_filelist = get_yahoo_astrace_filelist(filelist)
            reader = ASTraceReader.new(astrace_filelist)
            reader.each do |astrace|
                next if not astrace.reached
                astrace.src_asn = vp_asn
                atom_info_map[astrace.dst_ip].add_astrace(astrace)
            end
        end
        
        output_dir = File.join(YAHOO_OUTPUT_DIR, "atom")
        Dir.mkdir(output_dir) if not Dir.exist?(output_dir)
        output_fn = File.join(output_dir, "atom_#{vp}_#{startdatestr}_#{duration}d.txt")
        File.open(output_fn, 'w') do |f|
            f.puts "# dates: #{available_date.join(",")}"
            f.puts
            f.puts "dst_ip,num_of_tr,avg_latency,avg_ashop"
            atom_info_map.each do |ip, atom|
                f.puts "#{ip},#{atom.num_traceroute},#{atom.avg_latency},#{atom.avg_ashop}"
            end
        end
        puts "Output to #{output_fn}"
    end
end
end
