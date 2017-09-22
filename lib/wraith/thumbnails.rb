require "wraith"
require "wraith/helpers/logger"
require "parallel"
require "fileutils"
require "shellwords"

class Wraith::Thumbnails
  attr_reader :wraith

  def initialize(wraith)
    @wraith = wraith
  end

  def generate_thumbnails
    files = Dir.glob("#{wraith.directory}/**/*.png")
    Parallel.each(files, :in_processes => Parallel.processor_count) do |filename|
      next if @wraith.is_thumb? filename
      new_name = wraith.thumb_for(filename)
    end
  end
end
