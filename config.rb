module TopoConfig
    OUTPUT_DIR = File.expand_path("~/topodata")
    ITERATION_FILE = File.join(OUTPUT_DIR, "iterations.csv")

    REMOTE_DATA_URI = "arvind3@afterbuilt.corp.yahoo.com:/home/parthak/collector/download/"
    
    begin
        Dir.mkdir(OUTPUT_DIR) if not Dir.exist?(OUTPUT_DIR)
    end
end
