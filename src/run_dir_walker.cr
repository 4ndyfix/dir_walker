require "./dir_walker"

total_size : Int64 = 0

Dir.find(ENV["HOME"]) do |path|
  if File.directory? path
    if File.basename(path).starts_with?(".")
      Dir::Walker.prune # Don't look any further into this directory.
    end
  else
    total_size += File.size(path)
  end
end

puts total_size # .humanize
