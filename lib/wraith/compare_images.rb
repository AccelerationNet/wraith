require "wraith"
require "wraith/helpers/logger"
require "image_size"
require "open3"
require "parallel"
require "shellwords"

class Wraith::CompareImages
  include Logging
  attr_reader :wraith

  def initialize(config, lbl1=nil, lbl2=nil)
    @wraith = Wraith::Wraith.new(config)
    @label1 = lbl1
    @label2 = lbl2
  end

  def compare_image_by_position
    files = Dir.glob("#{wraith.directory}/*/*.png").sort
    Parallel.each(files.each_slice(2),
                  :in_processes => Parallel.processor_count) do |base, compare|
      compare_task(base, compare)
    end
  end

  def compare_images_by_label
    files = Dir.glob("#{wraith.directory}/*/*#{@label1}.png").sort
    Parallel.each(files, :in_processes => Parallel.processor_count) do |f1|
      f2 = f1.gsub("#{@label1}.png", "#{@label2}.png")
      if File.exists? f2
        compare_task(f1, f2)
      else
        logger.error("Missing file #{f2} writing dummy diff")
      end
    end
  end

  def create_invalid_image(filename, width)
    logger.warn "Using fallback image instead"
    invalid = File.expand_path("../../assets/invalid.jpg", File.dirname(__FILE__))
    FileUtils.mkdir_p(File.dirname(filename))
    FileUtils.cp invalid, filename
    set_image_width(filename, width)
  end

  def compare_images
    if @label1 and @label2
      compare_images_by_label
    else
      compare_images_by_position
    end
  end

  def percentage(img_size, px_value, info)
    pixel_count = (px_value / img_size) * 100
    rounded = pixel_count.round(2)
    return rounded
  end

  def compare_task(base, compare)
    logger.debug "Comparing #{base} and #{compare}"
    diff = base.gsub(/([a-zA-Z0-9]+).png$/, "_diff.png")
    info = base.gsub(/([a-zA-Z0-9]+).png$/, "_diff.txt")

    if File.exists? diff
      logger.info "Diff exists #{diff}"
      return
    end
    cmdline = "compare -dissimilarity-threshold 1 -fuzz #{wraith.fuzz} -metric AE -highlight-color #{wraith.highlight_color} #{base} #{compare.shellescape} #{diff}"
    px_value = Open3.popen3(cmdline) { |_stdin, _stdout, stderr, _wait_thr| stderr.read }.to_f
    begin
      img_size = ImageSize.path(diff).size.inject(:*)
      amount = percentage(img_size, px_value, info)
      File.open(info, "w") { |file|
        file.write({:from=>base, :to=>compare, :percent=>amount, :diff=>diff}.to_s)
      }
      logger.info "Saved diff #{info}"
    rescue
      logger.error "Error saving diff file #{info}"
    end

  end
end
