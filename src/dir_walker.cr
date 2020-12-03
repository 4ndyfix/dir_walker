class Dir
  # reopen class

  #
  # The `Dir::Walker` module supports the top-down traversal of a set of directories.
  #
  # For example, to total the size of all files under your home directory,
  # ignoring anything in a "dot" directory (e.g. $HOME/.ssh):
  #
  # ```code
  # require "dir_walker"
  #
  # total_size : Int64 = 0
  #
  # Dir::Walker.walk(ENV["HOME"]) do |path|
  #   if File.directory? path
  #     if File.basename(path).starts_with?(".")
  #       Dir::Walker.prune_path # Don't look any further into this directory.
  #     end
  #   else
  #     total_size += File.size(path)
  #   end
  # end
  #
  # puts total_size.humanize
  # ```
  module Walker
    extend self

    DEFAULT_SORT_PROC = Proc(String, String, Int32).new { |path1, path2| path1 <=> path2 }

    class Prune < Exception
    end

    # Calls the associated block with the path of every file and directory listed
    # as arguments, then traversaly on their subdirectories, and so on.
    # Optionally an alternative *sort_proc* per directory listing can be used.
    # Errors can be ignored also optionally.
    # See the `Dir::Walker` module documentation for an example.
    #
    def walk(*dirs : String, sort_proc = DEFAULT_SORT_PROC, ignore_error = false, &block : String ->)
      dirs.to_a.map! { |d| raise File::NotFoundError.new("Dir not found", file: d) unless Dir.exists? d; d.dup }.each do |dir|
        ary = [dir]
        while path = ary.shift?
          begin
            block.call path.dup
            if File.directory?(path) && !File.symlink?(path)
              begin
                children = Dir.children path
              rescue exc : IO::Error
                raise exc unless ignore_error
                next
              end
              children.map! { |child| File.join path, child }
              children.sort! &sort_proc
              children.reverse_each { |child| ary.unshift child }
            end
          rescue Walker::Prune
            next
          end
        end
      end
      nil
    end

    # Skips the current file or directory, restarting the loop with the next
    # entry. If the current file is a directory, that directory will not be
    # traversaly entered.
    #
    # See the `Find` module documentation for an example.
    #
    def prune_path
      raise Walker::Prune.new
    end
  end

  # shortcut or alias for `Dir::Walker::walk`
  def self.find(*dirs : String, sort_proc = Walker::DEFAULT_SORT_PROC, ignore_error = false, &block : String ->)
    Dir::Walker.walk *dirs, sort_proc: sort_proc, ignore_error: ignore_error, &block
  end

  # shortcut or alias for `Dir::Walker.prune_path`
  def self.prune_path
    Dir::Walker.prune_path
  end
end
