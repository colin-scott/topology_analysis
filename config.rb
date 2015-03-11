module TopoConfig
    # ITERATION_FILE = File.join(OUTPUT_DIR, "iterations.csv")
    READ_OUT = File.expand_path("readoutfile/readoutfile")
    READ_OUT_NO_NTOA = File.expand_path("readoutfile/readoutfile_no_ntoa")

    TARGET_LIST_FILE = File.expand_path("./ip_per_atom.txt")

    DATA_DIR = File.expand_path("./data")
    IPLANE_DATA_DIR = File.join(DATA_DIR, "iplane")
    YAHOO_DATA_DIR = File.join(DATA_DIR, "yahoo")

    OUTPUT_DIR = File.expand_path("./output/")
    IPLANE_OUTPUT_DIR = File.join(OUTPUT_DIR, "iplane")
    YAHOO_OUTPUT_DIR = File.join(OUTPUT_DIR, "yahoo")

    YAHOO_DATA_URI = "arvind3@afterbuilt.corp.yahoo.com:/home/parthak/collector/download/"
    IPLANE_DATA_URI = "http://iplane.cs.washington.edu/data/iplane_logs/"
    
    begin
        Dir.mkdir(DATA_DIR) if not Dir.exist?(DATA_DIR)
        Dir.mkdir(IPLANE_DATA_DIR) if not Dir.exist?(IPLANE_DATA_DIR)
        Dir.mkdir(YAHOO_DATA_DIR) if not Dir.exist?(YAHOO_DATA_DIR)
        Dir.mkdir(OUTPUT_DIR) if not Dir.exist?(OUTPUT_DIR)
        Dir.mkdir(IPLANE_OUTPUT_DIR) if not Dir.exist?(IPLANE_OUTPUT_DIR)
        Dir.mkdir(YAHOO_OUTPUT_DIR) if not Dir.exist?(YAHOO_OUTPUT_DIR)
    end
end
