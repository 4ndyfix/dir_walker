![](walker.png)

# dir_walker

The `Dir::Walker` module supports the top-down traversal of a set of directories.
It is similar to the standard method `Dir.glob("**/*")`, but has additional features like skip specific subdirectories, change the sort-oder of directory-listing (default: by name) or optionally ignore errors (IO::Error).

[![GitHub release](https://img.shields.io/github/release/4ndyfix/dir_walker.svg)](https://github.com/4ndyfix/dir_walker/releases)

The sourcecode is a port of the Ruby standard lib `Find`.

The feature generally is also available in many other languages. Examples are:
```
* Find.find(...)       # Ruby
* os.walk(...)         # Python
* File::Find.find(...) # Perl
* filepath.Walk(...)   # Go
```

## Installation

1. Add the dependency to your `shard.yml`:

```yaml
dependencies:
  dir_walker:
    github: 4ndyfix/dir_walker
```

2. Run `shards install`

## Usage

For example, to total the size of all files under your home directory,
ignoring anything in a "dot" directory (e.g. $HOME/.ssh):

```crystal
require "dir_walker"
  
total_size : Int64 = 0
  
Dir::Walker.walk(ENV["HOME"]) do |path|
  if File.directory? path
    if File.basename(path).starts_with?(".")
      Dir::Walker.prune_path # Don't look any further into this directory.
    end
  else
    total_size += File.size(path)
  end
end
  
puts total_size.humanize
```

## Contributing

1. Fork it (<https://github.com/4ndyfix/dir_walker/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [4ndyfix](https://github.com/4ndyfix) - creator and maintainer
