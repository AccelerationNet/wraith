require "yaml"
require "wraith/helpers/logger"
require "wraith/helpers/utilities"

class Wraith::Wraith
  attr_accessor :config
  attr_accessor :debug

  def initialize(url=nil, directory=nil, config=nil, yaml_passed = false)
    if config
      @config = yaml_passed ? config : open_config_file(config)
    end
    @config ={} unless @config
    domains = nil
    url = 'http://'+url unless url.start_with? 'http'
    if url
      pthname = url.gsub(/https?:\/\//,"").gsub(/\//, '_')
      if directory
        directory = "#{directory}/#{pthname}/"
      else
        directory = "~/.wraith/#{pthname}/"
      end
      domains = {pthname=> url}
    end
    @config = {'directory'=>directory, "domains"=>domains}.merge(@config)
    $logger.level = verbose ? Logger::DEBUG : $logger.level
  end

  def config
    @config
  end
  def gem_root
    File.expand_path '../../..', __FILE__
  end

  def open_config_file(config_name)
    possible_filenames = [
      config_name,
      "#{config_name}.yml",
      "#{config_name}.yaml",
      "configs/#{config_name}.yml",
      "configs/#{config_name}.yaml"
    ]

    possible_filenames.each do |filepath|
      filepath = File.expand_path(filepath)
      if filepath && File.exist?(filepath)
        config = File.open filepath
        return YAML.load config
      end
    end
    fail ConfigFileDoesNotExistError, "unable to find config \"#{config_name}\""
  end

  def directory
    # Legacy support for those using array configs
    d = @config["directory"]
    d = d.first if d.is_a?(Array)
    d = File.expand_path(d)
    FileUtils.mkdir_p(d) unless File.exist? d
    d = File.realpath(d)
    d = "~/.wraith/#{base_domain}/" unless d
    d
  end

  def history_dir
    @config["history_dir"] || false
  end

  def engine
    engine = @config["browser"]
    engine = "phantomjs" unless engine
    # Legacy support for those using the old style "browser: \n phantomjs: 'casperjs'" configs
    engine = engine.values.first if engine.is_a? Hash
    engine
  end

  def snap_file
    @config["snap_file"] ? convert_to_absolute(@config["snap_file"]) : snap_file_from_engine(engine)
  end

  def snap_file_from_engine(engine)
    path_to_js_templates = File.dirname(__FILE__) + "/javascript"
    case engine
    when "phantomjs"
      path_to_js_templates + "/phantom.js"
    when "casperjs"
      path_to_js_templates + "/casper.js"
    # @TODO - add a SlimerJS option
    else
      $logger.error "Wraith does not recognise the browser engine '#{engine}'"
    end
  end

  def before_capture
    @config["before_capture"] ? convert_to_absolute(@config["before_capture"]) :
      convert_to_absolute('javascript/disable_javascript--phantom.js')
  end

  def widths
    @config["screen_widths"] || ['500x2000', 1800]
  end

  def resize
    # @TODO make this default to true, once it's been tested a bit more thoroughly
    @config["resize_or_reload"] ? (@config["resize_or_reload"] == "resize") : false
  end

  def domains
    @config["domains"]
  end

  def base_domain
    domains[base_domain_label]
  end

  def comp_domain
    domains[comp_domain_label]
  end

  def base_domain_label
    domains.keys[0]
  end

  def comp_domain_label
    domains.keys[1]
  end

  def spider_file
    @config["spider_file"] ? @config["spider_file"] : "#{directory}/spider.txt"
  end


  def spider_depth
    @config["spider_depth"] || false
  end

  def spider_days
    s = @config["spider_days"]
    s = s[0] if s.kind_of?(Array)
    s = 180 if not s
    return s
  end

  def sitemap
    @config["sitemap"]
  end

  def spider_skips
    @config["spider_skips"]
  end

  def paths
    p = @config["paths"]
    if !p && File.exists?(spider_file)
      $logger.debug "Read the spider file...."
      p = File.read(spider_file)
      @config["paths"] = eval(p)
    else
      p
    end
  end

  def fuzz
    @config["fuzz"] || '2%'
  end

  def highlight_color
    @config["highlight_color"] ? @config["highlight_color"] : "blue"
  end

  def threshold
    @config["threshold"] ? @config["threshold"] : 5
  end

  def gallery_template
    default = "slideshow_new_template"
    if @config["gallery"].nil?
      default
    else
      @config["gallery"]["template"] || default
    end
  end

  def thumb_height
    default = 200
    if @config["gallery"].nil?
      default
    else
      @config["gallery"]["thumb_height"] || default
    end
  end

  def thumb_width
    default = 200
    if @config["gallery"].nil?
      default
    else
      @config["gallery"]["thumb_width"] || default
    end
  end

  def phantomjs_options
    @config["phantomjs_options"]
  end

  def verbose
    @config["verbose"] || @debug || false
  end

  def num_threads
    (@config["num_threads"] || 8).to_i
  end

  def clear_shots_folder
    FileUtils.rm_rf("#{dir}")
    FileUtils.mkdir_p("#{dir}")
  end

  def remove_labeled_shots(label)
    Dir["#{directory}/**/*#{label}.png"].each do |filepath|
      $logger.debug "Removing labeled file #{filepath}"
      File.delete(filepath)
    end
    Dir["#{directory}/**/*#{label}"].each do |filepath|
      $logger.debug "Removing labeled file #{filepath}"
      File.delete(filepath)
    end
  end
  def create_folders
    unless File.directory?(directory)
      FileUtils.mkdir_p(directory)
    end
  end
end
