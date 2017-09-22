require "wraith"
require "wraith/helpers/logger"
require "image_size"
require "open3"
require "parallel"
require "shellwords"

class Wraith::CompareImages
  attr_reader :wraith

  def initialize(wraith, lbl1=nil, lbl2=nil)
    @wraith = wraith
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
    files = Dir.glob("#{wraith.directory}/#{@label1}/**/*.png").sort
    Parallel.each(files, :in_processes => Parallel.processor_count) do |f1|
      next if f1 =~ /\.tn\.png$/
      f2 = f1.gsub("#{wraith.directory}/#{@label1}/", "#{wraith.directory}/#{@label2}/")
      diff = f1.gsub("#{wraith.directory}/#{@label1}/", "#{wraith.directory}/diff/")
      if File.exists? f2
        compare_task(f1, f2, diff)
      else
        $logger.error("Missing file #{f2} writing dummy diff")
      end
    end
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

  def compare_task(base, compare, diff_dir)
    $logger.debug "Comparing #{base} and #{compare}"
    diff = diff_dir.gsub(/\.png$/, ".diff.png")
    info = diff_dir.gsub(/\.png$/, ".diff.txt")
    unless File.directory?(File.dirname(diff))
      FileUtils.mkdir_p(File.dirname(diff))
    end
    if File.exists? diff
      $logger.info "Diff exists #{diff}"
      return
    end
    cmdline = "compare -dissimilarity-threshold 1 -fuzz #{wraith.fuzz} -metric AE -highlight-color #{wraith.highlight_color} #{base} #{compare.shellescape} #{diff}"
    px_value = Open3.popen3(cmdline) { |_stdin, _stdout, stderr, _wait_thr| stderr.read }.to_f
    begin
      img = ImageSize.path(diff)
      img_size = img.size.inject(:*)
      amount = percentage(img_size, px_value, info)

      File.open(info, "w") { |file|
        file.write({:from=>base,
                    :to=>compare,
                    size: img.size.join(","),
                    :width=> img.width,
                    :height=> img.height,
                    :percent=>amount,
                    :diff=>diff}.to_s)
      }
      $logger.info "Saved diff #{info}"
    rescue Exception => e
      $logger.error "Error saving diff file #{info}, #{e}"
    end

  end
end
