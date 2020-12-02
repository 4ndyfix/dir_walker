require "spec"
require "file_utils"
require "../src/dir_walker"

def useTmpDir(&block : String ->)
  tmp_dir = File.tempname
  begin
    Dir.mkdir tmp_dir, 0o0700
    block.call tmp_dir
  ensure
    FileUtils.rm_r tmp_dir
  end
end

def create_paths(base : String, paths : Array(Array(String)))
  expected = [base]
  paths.each do |items|
    joined = File.join([base, items].flatten)
    if File.basename(joined).includes? "DIR"
      FileUtils.mkdir joined
    elsif joined.includes? "SLINK"
      joined = create_slink joined
    else
      File.touch joined
    end
    expected << joined
    sleep 0.000_001 # 1us, because of distinct directory mtime values
  end
  expected
end

def create_slink(joined : String)
  sepa = File::SEPARATOR
  location, term = joined.split "#{sepa}SLINK#{sepa}"
  items = term.split sepa
  source, destination = File.join(items[0..-2]), items.last
  Dir.cd location do
    File.symlink source, destination
  end
  File.join location, destination
end

def windows?
  File::SEPARATOR == '\\'
end

lib LibC
  fun getuid : Int32
end

def root_user?
  LibC.getuid == 0
end
