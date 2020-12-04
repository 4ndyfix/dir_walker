require "./spec_helper"

describe Dir::Walker do
  it "finds only empty start dir" do
    useTmpDir do |dir|
      ary = [] of String
      Dir::Walker.walk(dir) { |path| ary << path }
      ary.should eq [dir]
    end
  end

  it "finds some directories and files sorted by name" do
    useTmpDir do |base|
      expected = create_paths(base, [
        ["a_file"],
        ["b_DIR"],
        ["b_DIR", "a_file"],
        ["b_DIR", "b_file"],
        ["c_DIR"],
      ])
      result = [] of String
      Dir::Walker.walk(base) { |path| result << path }
      result.should eq expected
    end
  end

  it "finds some directories and files sorted by name in two base dirs" do
    useTmpDir do |base1|
      useTmpDir do |base2|
        expected = create_paths(base1, [
          ["a_file"],
          ["b_DIR"],
          ["b_DIR", "a_file"],
          ["b_DIR", "b_file"],
          ["c_DIR"],
        ])
        expected.concat create_paths(base2, [
          ["d_file"],
          ["e_DIR"],
          ["e_DIR", "d_file"],
          ["e_DIR", "e_file"],
          ["f_DIR"],
        ])
        result = [] of String
        Dir::Walker.walk(base1, base2) { |path| result << path }
        result.should eq expected
      end
    end
  end

  it "finds some directories and files sorted by age" do
    useTmpDir do |base|
      expected = create_paths(base, [
        ["y_DIR"],
        ["y_DIR", "z_DIR"],
        ["y_DIR", "z_DIR", "b_file"],
        ["y_DIR", "z_DIR", "a_file"],
        ["y_DIR", "z_DIR", "c_file"],
        ["x_DIR"],
        ["x_DIR", "z_DIR"],
        ["x_DIR", "z_DIR", "b_file"],
        ["x_DIR", "z_DIR", "a_file"],
        ["x_DIR", "z_DIR", "c_file"],
      ], reset_mtime: true)
      result = [] of String
      sort_proc = Proc(String, String, Int32).new { |a, b| File.info(a).modification_time <=> File.info(b).modification_time }
      Dir::Walker.walk(base, sort_proc: sort_proc) { |path| result << path }
      result.should eq expected
    end
  end

  it "finds some entries excluding a named directory by prune" do
    useTmpDir do |base|
      expected = create_paths(base, [
        ["x_DIR"],
        ["x_DIR", "a_file"],
        ["x_DIR", "b_file"],
        ["y_DIR"],
        ["y_DIR", "a_file"],
        ["y_DIR", "b_file"],
        ["z_DIR"],
        ["z_DIR", "a_file"],
        ["z_DIR", "b_file"],
      ])
      result = [] of String
      Dir::Walker.walk(base) do |path|
        Dir::Walker.prune_path if File.directory?(path) && File.basename(path).starts_with? "y_DIR"
        result << path
      end
      expected.reject! { |path| path.includes? "y_DIR" }
      result.should eq expected
    end
  end

  it "finds some entries by using method shortcuts (aliases)" do
    useTmpDir do |base|
      expected = create_paths(base, [
        ["x_DIR"],
        ["x_DIR", "a_file"],
        ["x_DIR", "b_file"],
        ["y_DIR"],
        ["y_DIR", "a_file"],
        ["y_DIR", "b_file"],
        ["z_DIR"],
        ["z_DIR", "a_file"],
        ["z_DIR", "b_file"],
      ])
      result = [] of String
      Dir.find(base) do |path|
        Dir.prune_path if File.directory?(path) && File.basename(path).starts_with? "y_DIR"
        result << path
      end
      expected.reject! { |path| path.includes? "y_DIR" }
      result.should eq expected
    end
  end

  it "raises File::NotFoundError: Dir not found" do
    ary = [] of String
    expect_raises File::NotFoundError, "Dir not found" do
      Dir::Walker.walk("__NOT_EXISTING_DIR__") { |path| ary << path }
    end
  end

  unless root_user? # because root can read anything
    it "raises File::AccessDeniedError: Permission denied, because not readable" do
      useTmpDir do |base|
        expected = create_paths(base, [
          ["x_DIR"],
          ["x_DIR", "file_y"],
        ])
        begin
          File.chmod expected[-2], 0o300 # dir not readable
          ary = [] of String
          expect_raises File::AccessDeniedError, "Permission denied" do
            Dir::Walker.walk(base) { |path| ary << path }
          end
        ensure
          File.chmod expected[-2], 0o700 # for cleanup
        end
      end
    end
  end

  unless root_user?
    it "ignores File::AccessDeniedError: Permission denied" do
      useTmpDir do |base|
        expected = create_paths(base, [
          ["x_DIR"],
          ["x_DIR", "file_y"],
        ])
        begin
          File.chmod expected[-2], 0o300 # dir not readable
          result = [] of String
          Dir::Walker.walk(base, ignore_error: true) { |path| result << path }
          expected.delete_at(-1)
          result.should eq expected
        ensure
          File.chmod expected[-1], 0o700 # for cleanup
        end
      end
    end
  end

  unless root_user?
    it "raises File::AccessDeniedError: Permission denied, because not searchable" do
      useTmpDir do |base|
        expected = create_paths(base, [
          ["x_DIR"],
          ["x_DIR", "file_y"],
        ])
        begin
          File.chmod expected[-2], 0o600 # dir not searchable
          ary = [] of String
          expect_raises File::AccessDeniedError, "Permission denied" do
            Dir::Walker.walk(base) { |path| ary << path }
          end
        ensure
          File.chmod expected[-2], 0o700 # for cleanup
        end
      end
    end
  end

  unless windows?
    it "finds some directories, files and symlinks" do
      useTmpDir do |base|
        expected = create_paths(base, [
          ["a_file"],
          ["SLINK", "a_file", "a_file_slink"],
          ["b_DIR"],
          ["b_DIR", "a_file"],
          ["b_DIR", "b_file"],
          ["b_DIR", "SLINK", "b_file", "b_slink"],
        ])
        result = [] of String
        symlinks = [] of String
        Dir::Walker.walk base do |path|
          result << path
          symlinks << path if File.symlink? path
        end
        result.should eq expected
        symlinks.size.should eq 2
      end
    end
  end

  unless windows?
    it "doesn't follow a directory-symlink" do
      useTmpDir do |base|
        expected = create_paths(base, [
          ["b_DIR"],
          ["b_DIR", "a_file"],
          ["c_DIR"],
          ["c_DIR", "SLINK", "..", "b_DIR", "b_dir_slink"],
        ])
        result = [] of String
        symlinks = [] of String
        Dir::Walker.walk base do |path|
          result << path
          symlinks << path if File.symlink? path
        end
        result.should eq expected
        symlinks.size.should eq 1
      end
    end
  end

  unless windows?
    it "raises File::NotFoundError: No such file or directory, because of dangling symlink" do
      useTmpDir do |base|
        expected = create_paths(base, [
          ["a_DIR"],
          ["a_DIR", "SLINK", "non_existing_file", "dangling_slink"],
        ])
        result = [] of String
        symlinks = [] of String
        Dir::Walker.walk base do |path|
          result << path
          symlinks << path if File.symlink? path
        end
        result.should eq expected
        symlinks.size.should eq 1
        symlink = expected.last
        expect_raises File::NotFoundError, "No such file or directory" do
          File.info symlink
        end
        expect_raises File::NotFoundError, "No such file or directory" do
          Dir::Walker.walk(base) { |path| File.info path }
        end
      end
    end
  end
end
