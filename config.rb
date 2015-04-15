require 'set'

module TopoConfig
    # ITERATION_FILE = File.join(OUTPUT_DIR, "iterations.csv")
    READ_OUT = File.expand_path("readoutfile/readoutfile")
    READ_OUT_NO_NTOA = File.expand_path("readoutfile/readoutfile_no_ntoa")

    DATA_DIR = File.expand_path("./data")
    IPLANE_DATA_DIR = File.join(DATA_DIR, "iplane")
    YAHOO_DATA_DIR = File.join(DATA_DIR, "yahoo")

    YAHOO_AS_LIST_FILE = File.join(DATA_DIR, "yahoo_asns.csv")
    TARGET_LIST_FILE = File.join(DATA_DIR, "ip_per_atom.txt")

    OUTPUT_DIR = File.expand_path("./output/")
    IPLANE_OUTPUT_DIR = File.join(OUTPUT_DIR, "iplane")
    YAHOO_OUTPUT_DIR = File.join(OUTPUT_DIR, "yahoo")

    YAHOO_DATA_URI = "arvind3@afterbuilt.corp.yahoo.com:/home/parthak/collector/download/"
    IPLANE_DATA_URI = "http://iplane.cs.washington.edu/data/iplane_logs/"

    IPLANE_BLACKLIST = Set.new [
        "planetlab-4.eecs.cwru.edu",
    ]
    
    begin
        Dir.mkdir(DATA_DIR) if not Dir.exist?(DATA_DIR)
        Dir.mkdir(IPLANE_DATA_DIR) if not Dir.exist?(IPLANE_DATA_DIR)
        Dir.mkdir(YAHOO_DATA_DIR) if not Dir.exist?(YAHOO_DATA_DIR)
        Dir.mkdir(OUTPUT_DIR) if not Dir.exist?(OUTPUT_DIR)
        Dir.mkdir(IPLANE_OUTPUT_DIR) if not Dir.exist?(IPLANE_OUTPUT_DIR)
        Dir.mkdir(YAHOO_OUTPUT_DIR) if not Dir.exist?(YAHOO_OUTPUT_DIR)
    end

    def load_target_list
        targets = Set.new
        File.open(TARGET_LIST_FILE).each_line do |ip|
            targets << ip.chomp
        end
        targets
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
end
