require 'set'

module TopoConfig
    # ITERATION_FILE = File.join(OUTPUT_DIR, "iterations.csv")
    READ_OUT = File.expand_path("readoutfile/readoutfile")
    READ_OUT_NO_NTOA = File.expand_path("readoutfile/readoutfile_no_ntoa")

    DATA_DIR = File.expand_path("./data")
    IPLANE_DATA_DIR = File.join(DATA_DIR, "iplane")
    YAHOO_DATA_DIR = File.join(DATA_DIR, "yahoo")

    YAHOO_AS_LIST_FILE = File.join(DATA_DIR, "yahoo_asns.csv")
    IP_TARGET_LIST_FILE = File.join(DATA_DIR, "ip_per_atom.txt")

    OUTPUT_DIR = File.expand_path("./output/")
    IPLANE_OUTPUT_DIR = File.join(OUTPUT_DIR, "iplane")
    YAHOO_OUTPUT_DIR = File.join(OUTPUT_DIR, "yahoo")

    YAHOO_DATA_URI = "arvind3@afterbuilt.corp.yahoo.com:/home/parthak/collector/download/"
    IPLANE_DATA_URI = "http://iplane.cs.washington.edu/data/iplane_logs/"

    VP_COUNT = 16

    IPLANE_BLACKLIST = [
        "planetlab-4.eecs.cwru.edu",
        "cs.ucr.edu",
        "cs.uic.edu",
        "scie.uestc.edu.cn",
        "tagus.ist.utl.pt",
        "cs.ucy.ac.cy",
        "eecs.umich.edu",
        "planetlab2-buenosaires.lan.redclara.net",
        "planetlab2-saopaulo.lan.redclara.net",
        "planetlab2.diku.dk",
        "planetlab2.ics.forth.gr",
        "cs.columbia.edu",
        "planetlab2.ie.cuhk.edu.hk",
        "comp.nus.edu.sg",
        "cs.otago.ac.nz",
        "ecs.vuw.ac.nz",
    ]
    IPLANE_SKIP_ASLIST = Set.new [
        1916, 4134, 2611, 2907, 559, 553, 2852, 786, 680, 14041, 2500, 2614
    ]
    YAHOO_BLACKLIST = [
        "r01.ycpi.inc.yahoo.net",
        "r1.ycpi.idc.yahoo.net",
        "r1.ycpi.vnb.yahoo.net",
        "r1.ycpi.vnc.yahoo.net",
        "r1.ycpi.aea.yahoo.net",
        "r1.ycpi.ph1.yahoo.net",
        "r1.ycpi.ph2.yahoo.net",
    ]
    
    @@IP_TARGET_LIST = nil
    @@IPLANE_VP_INFO = nil
    @@YAHOO_VP_INFO  = nil

    begin
        Dir.mkdir(DATA_DIR) if not Dir.exist?(DATA_DIR)
        Dir.mkdir(IPLANE_DATA_DIR) if not Dir.exist?(IPLANE_DATA_DIR)
        Dir.mkdir(YAHOO_DATA_DIR) if not Dir.exist?(YAHOO_DATA_DIR)
        Dir.mkdir(OUTPUT_DIR) if not Dir.exist?(OUTPUT_DIR)
        Dir.mkdir(IPLANE_OUTPUT_DIR) if not Dir.exist?(IPLANE_OUTPUT_DIR)
        Dir.mkdir(YAHOO_OUTPUT_DIR) if not Dir.exist?(YAHOO_OUTPUT_DIR)
    end

    def skip_iplane?(url)
        IPLANE_BLACKLIST.each do |suffix|
            return true if url.end_with?(suffix)
        end
        return false
    end

    def skip_yahoo?(url)
        if YAHOO_BLACKLIST.include?(url)
            return true
        else
            return false
        end
    end

    def select_iplane_vps(vplist, selected_as=nil)
        vp_info = load_iplane_vp_info

        filtered_vplist = {}
        vplist.each do |vp|
            next if skip_iplane?(vp)
            vp_asn = vp_info[vp][1]
            next if IPLANE_SKIP_ASLIST.include?(vp_asn)
            next if filtered_vplist.has_key?(vp_asn)
            filtered_vplist[vp_asn] = vp
        end

        if selected_as.nil?
            selected_as = filtered_vplist.keys.sample(VP_COUNT)
        end
        selected_vps = []
        filtered_vplist.each do |vp_asn, vp|
            selected_vps << vp if selected_as.include?(vp_asn)
        end

        return [selected_vps, selected_as]
    end

    def select_yahoo_vps(vplist)
        vp_info = load_yahoo_vp_info
        filtered_vplist = {}
        vplist.each do |vp|
            next if skip_yahoo?(vp)
            vp_asn = vp_info[vp][1]
            next if filtered_vplist.has_key?(vp_asn)
            filtered_vplist[vp_asn] = vp
        end
        return filtered_vplist.values
    end

    def load_target_list
        if @@IP_TARGET_LIST.nil?
            @@IP_TARGET_LIST = Set.new
            File.open(IP_TARGET_LIST_FILE).each_line do |ip|
                @@IP_TARGET_LIST << ip.chomp
            end
        end
        @@IP_TARGET_LIST
    end

    def load_yahoo_aslist
        aslist = Set.new
        File.open(YAHOO_AS_LIST_FILE).each do |line|
            next if not line =~ /^\d/
            asn = line.split(',')[1].to_i
            aslist << asn if asn < 64496 # don't include private asn
        end
        aslist
    end

    def load_iplane_vp_info
        if @@IPLANE_VP_INFO.nil?
            vp_info = {}
            File.open(File.join(DATA_DIR, "iplane_vps.txt")).each do |line|
                vp, ip, asn = line.split()
                vp_info[vp] = [ip, asn.to_i]
            end
            @@IPLANE_VP_INFO = vp_info
        end
        @@IPLANE_VP_INFO
    end

    def load_yahoo_vp_info
        if @@YAHOO_VP_INFO.nil?
            vp_info = {}
            File.open(File.join(DATA_DIR, "yahoo_vps.txt")).each do |line|
                vp, ip, asn = line.split()
                vp_info[vp] = [ip, asn.to_i]
            end
            @@YAHOO_VP_INFO = vp_info
        end
        @@YAHOO_VP_INFO
    end
end
