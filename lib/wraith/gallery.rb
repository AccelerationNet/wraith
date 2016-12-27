require "erb"
require "pathname"
require "pp"
require "fileutils"
require "wraith/wraith"
require "wraith/helpers/logger"

class Wraith::GalleryGenerator
  include Logging
  attr_reader :wraith

  MATCH_FILENAME = /(\S+)_(\S+)\.\S+/

  def initialize(config)
    @wraith = Wraith::Wraith.new(config)
    @location = wraith.directory
  end

  def generate_gallery_data (only_diff=true)
    @dirs = []
    idx = -1
    Dir.glob("#{@location}/*/*_diff.txt").each do |fn|
      idx += 1
      info = eval(File.read(fn))
      if not info[:diff]
        info[:diff] = info[:from].gsub(/([a-zA-Z0-9]+).png$/, "_diff.png")
      end
      pnf = Pathname.new(info[:from])
      match = MATCH_FILENAME.match(pnf.basename.to_s)
      info[:from] = info[:from].gsub("#{wraith.directory}/", "")
      info[:fromTH] = "thumbnails/#{info[:from]}"
      info[:to] = info[:to].gsub("#{wraith.directory}/", "")
      info[:toTH] = "thumbnails/#{info[:to]}"
      info[:diff] = info[:diff].gsub("#{wraith.directory}/", "")
      info[:diffTH] = "thumbnails/#{info[:diff]}"
      info[:size] = match[1]
      info[:dir] = pnf.dirname.to_s
      info[:idx] = idx
      @dirs << info
    end
    if only_diff
      @dirs=@dirs.select { |x| (x[:percent]||0).to_f > @wraith.threshold}
    end
    @dirs = @dirs.sort do |x,y|
      s1 = (x[:percent]||0).to_f
      s2 = (y[:percent]||0).to_f
      return 1 if s1 < s2
      return -1 if s1 > s2
      f1 = (x[:from]||"")
      f2 = (y[:from]||"")
      return 1 if f1 > f2
      return -1 if f1 < f2
      0
    end
  end

  def generate_diff_gallery(with_path="")
    dest1 = "#{@location}/gallery_diff.html"
    dest2 = "#{@location}/gallery_full.html"
    d1 = generate_gallery_data true
    d2 = generate_gallery_data false
    #logger.debug directories
    template = File.expand_path("gallery_template/#{wraith.gallery_template}.erb", File.dirname(__FILE__))
    generate_html(@location, d1, template, dest1, with_path)
    generate_html(@location, d2, template, dest2, with_path)
    report_gallery_status dest1
    report_gallery_status dest2
  end

  def generate_gallery(with_path = "")
    generate_diff_gallery
  end

  def generate_html(location, diffs, template, destination, path)
    template = File.read(template)
    locals = {
      :location    => location,
      :diffs       => diffs,
      :path        => path,
      :threshold   => wraith.threshold
    }
    html = ERB.new(template).result(ErbBinding.new(locals).get_binding)
    File.open(destination, "w") do |outf|
      outf.write(html)
    end
  end

  def report_gallery_status(dest)
    logger.info "Gallery generated"
    failed = check_failed_shots
    prompt_user_to_open_gallery dest
    exit 1 if failed
  end

  def prompt_user_to_open_gallery(dest)
    logger.info "\nView the gallery in your browser:"
    logger.info "\t file://" + Dir.pwd + "/" + dest
  end

  class ErbBinding < OpenStruct
    def get_binding
      binding
    end
  end
end
