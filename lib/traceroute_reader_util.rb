
# Abstract class
class TracerouteFileReader
  ReadOutFile = "./readoutfile/readoutfile_no_ntoa"

  def initialize(filename, database)
    @filename = filename
    @vp = get_vp_from_filename(filename)
    @database = database
  end

  def get_vp_from_filename(filename)
    filename.gsub("trace.out", "")
  end
end

