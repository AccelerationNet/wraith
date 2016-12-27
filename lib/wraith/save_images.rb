require "parallel"
require 'timeout'
require "shellwords"
require "wraith"
require "wraith/helpers/capture_options"
require "wraith/helpers/logger"
require "wraith/helpers/save_metadata"
require "wraith/helpers/utilities"

#http://stackoverflow.com/questions/8292031/ruby-timeouts-and-system-commands
def exec_with_timeout(cmd, timeout, logoutput=true)
  begin
    # stdout, stderr pipes
    rout, wout = IO.pipe
    rerr, werr = IO.pipe
    stdout, stderr = nil


    pid = Process.spawn(cmd, pgroup: true, :out => wout, :err => werr)

    Timeout.timeout(timeout) do
      Process.waitpid(pid)

      # close write ends so we can read from them
      wout.close
      werr.close

      stdout = rout.readlines.join
      stderr = rerr.readlines.join
    end

  rescue Timeout::Error
    $logger.error "Killed child phantom js: #{cmd}"
    Process.kill(-9, pid)
    Process.detach(pid)
  ensure
    wout.close unless wout.closed?
    werr.close unless werr.closed?
    # dispose the read ends of the pipes
    rout.close
    rerr.close
  end
  $logger.info "#{stdout}" if logoutput
  stdout
end

class Wraith::SaveImages
  attr_reader :wraith, :history, :meta

  def initialize(wraith, history = false, yaml_passed = false, label=nil)
    @wraith = wraith
    @history = history
    @meta = SaveMetadata.new(@wraith, history, label=label)
    $logger.info "Save meta with label #{label}"
  end

  def check_paths
    wraith.paths
  end

  def save_images
    jobs = define_jobs
    parallel_task(jobs)
  end

  def define_jobs
    jobs = []
    check_paths.each do |label, options|
      settings = CaptureOptions.new(options, wraith)

      if settings.resize
        jobs += define_individual_job(label, settings, wraith.widths)
      else
        wraith.widths.each do |width|
          jobs += define_individual_job(label, settings, width)
        end
      end
    end
    jobs
  end

  def define_individual_job(label, settings, width)
    base_file_name    = meta.file_names(width, label, meta.base_label)
    compare_file_name = meta.file_names(width, label, meta.compare_label)
    jobs = []
    jobs << [label, settings.path, prepare_widths_for_cli(width), settings.base_url,    base_file_name,    settings.selector, wraith.before_capture, settings.before_capture]
    jobs << [label, settings.path, prepare_widths_for_cli(width), settings.compare_url, compare_file_name, settings.selector, wraith.before_capture, settings.before_capture] unless settings.compare_url.nil?
    jobs
  end

  def prepare_widths_for_cli(width)
    # prepare for the command line. [30,40,50] => "30,40,50"
    width = width.join(",") if width.is_a? Array
    width
  end

  def run_command(command)
    exec_with_timeout(command, 60)
  end

  def parallel_task(jobs)
    Parallel.each(jobs, :in_threads => wraith.num_threads) do |_label, _path, width, url, filename, selector, global_before_capture, path_before_capture|
      begin
        command = construct_command(width, url, filename, selector, global_before_capture, path_before_capture)
        attempt_image_capture(command, filename)
      rescue => e
        $logger.error e
      end
    end
  end

  def construct_command(width, url, file_name, selector, global_before_capture, path_before_capture)
    width    = prepare_widths_for_cli(width)
    selector = selector.gsub '#', '\#' # make sure id selectors aren't escaped in the CLI
    global_before_capture = convert_to_absolute global_before_capture
    path_before_capture   = convert_to_absolute path_before_capture

    command_to_run = "#{meta.engine} #{wraith.phantomjs_options} '#{wraith.snap_file}' '#{url}' '#{width}' '#{file_name}' '#{selector}' '#{global_before_capture}' '#{path_before_capture}'"
    command_to_run
  end

  def attempt_image_capture(capture_page_image, filename)
    unless File.directory?(File.dirname(filename))
      FileUtils.mkdir_p(File.dirname(filename))
    end
    return true if image_was_created filename
    max_attempts = 10
    max_attempts.times do |i|
      run_command capture_page_image
      return true if image_was_created filename
      $logger.warn "Failed to capture image #{filename} on attempt number #{i + 1} of #{max_attempts} \n  ----  #{capture_page_image}\n"
    end
    fail "Unable to capture image #{filename} after #{max_attempts} attempt(s)" unless image_was_created filename
  end

  def image_was_created(filename)
    # @TODO - need to check if the image was generated even if in resize mode
    if File.exist? filename
      $logger.info "--> Image saved #{filename}"
      return true
    end
    return false
  end

  def set_image_width(image, width)
    `convert #{image.shellescape} -background none -extent #{width}x0 #{image.shellescape}`
  end
end
