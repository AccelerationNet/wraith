require "yaml"
require "wraith/helpers/logger"
require "wraith/helpers/utilities"

class Wraith::Wraith
  attr_accessor :config
  attr_accessor :debug
  attr_accessor :host

  def initialize(conf_dict=false, config_file=nil)
    @config = conf_dict || {}
    config_file = @config[:config_file] unless config_file
    if config_file
      $logger.debug("Trying top open conf: #{config_file}")
      @config = @config.merge(open_config_file(config_file))
    end
    @file_tag = conf_dict["label"] or conf_dict[:label]
    domains = nil
    url = @config[:url].chomp('/')
    directory = @config[:directory]
    url  = 'http://'+url unless url.start_with? 'http'
    if url
      pthname = url.gsub(/https?:\/\//,"").gsub(/\/\//,'/').gsub(/\//, '_')
      if directory
        directory = "#{directory}/#{pthname}/"
      else
        directory = "~/.wraith/#{pthname}/"
      end
      domains = {pthname=> url}
    end
    @config = {'directory'=>directory, "domains"=>domains, "ip"=>ip}.merge(@config)
    $logger.level = verbose ? Logger::DEBUG : $logger.level
    urlO = URI(url)
    self.host = urlO.host

    if dockerized?
      $logger.debug "Running Dockerized"
      if ip

        $logger.info "Setting /etc/hosts for : #{ip} #{host}"
        File.open("/etc/hosts", "w+") { |file|
          file.write("\n#{ip} #{host}\n")
        }
        $logger.debug "Clearing Ip"
        ip = nil # we have our hosts file to handle this
      end
    else
      $logger.debug "Running as standalone ruby script (non-docker)"
      if ip
        $logger.warning()
        raise Exception.new("Run the dockerized variant of the script to access by-IP crawls")
      end
    end

  end

  def dockerized?
    ENV['DOCKERIZED'] == "true"
  end

  def save_crawled?
    false
  end

  def config
    @config
  end
  def gem_root
    File.expand_path '../../..', __FILE__
  end

  def open_config_file(config_name)
    return nil unless config_name
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

  def ip
    @config[:ip] or @config['ip']
  end
  def ip= (val)
    @config[:ip] = @config['ip'] = val
  end


  def directory
    # Legacy support for those using array configs
    d = @config["directory"]
    d = d.first if d.is_a?(Array)
    d = File.expand_path(d)
    FileUtils.mkdir_p(d) unless File.exist? d
    d = File.realpath(d)
    d = "~/.wraith/#{base_domain}" unless d
    d.chomp('/')
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
    @config["before_capture"] ? convert_to_absolute(@config["before_capture"]) : false
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

  def save_label
    return @file_tag if @file_tag
    return "_latest" if @history
    return ""
  end

  def spider_file
    @config["spider_file"] ? @config["spider_file"] : "#{directory}/spider.txt"
  end

  def spider_save_path(pth)
    pth = pth.gsub(/^\//, '').chomp('/')
    if !( /.html?/ =~ pth )
      pth = "#{pth}/index.html"
    end
    pth = "#{directory}/#{save_label}/#{pth}"
    pth
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

  def meta_label
    return @file_tag if @file_tag
    return "_latest" if @history
    return ""
  end

  def file_names(width, label, domain_label)
    width = "MULTI" if width.is_a? Array
    "#{directory}/#{meta_label}/#{label}/#{engine}_#{width}_#{domain_label}.png"
  end

  def base_label
    "#{base_domain_label}"
  end

  def compare_label
    "#{comp_domain_label}"
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
    @config["debug"] || @config["verbose"] || @debug || false
  end

  def num_threads
    (@config["num_threads"] || 8).to_i
  end

  def clear_shots_folder
    FileUtils.rm_rf("#{dir}")
    FileUtils.mkdir_p("#{dir}")
  end

  def remove_labeled_shots(label)
    Dir["#{directory}/#{label}/**/*.png"].each do |filepath|
      $logger.debug "Removing labeled file #{filepath}"
      File.delete(filepath)
    end
    Dir["#{directory}/**/*#{label}"].each do |filepath|
      $logger.debug "Removing labeled file #{filepath}"
      File.delete(filepath) if File.file?(filepath)
    end
  end
  def create_folders
    unless File.directory?(directory)
      FileUtils.mkdir_p(directory)
    end
  end

  def is_thumb? (pth)
    pth =~ /\.tn\.png$/
  end

  def thumb_for(pth)
    thpth = pth
    if not is_thumb? pth
      thpth = pth.gsub(/\.png$/, ".tn.png")
    end
    if File.exists?( pth ) and not File.exists?( thpth )
      make_thumbnail_image(pth, thpth)
    end
    thpth
  end

  def make_thumbnail_image(png_path, output_path)
    return true if File.exists? output_path
    unless File.directory?(File.dirname(output_path))
      FileUtils.mkdir_p(File.dirname(output_path))
    end

    `convert #{png_path.shellescape} -thumbnail 200 -crop #{self.thumb_width.to_s}x#{self.thumb_height.to_s}+0+0 #{output_path.shellescape}`
    $logger.info "Created thumbnail #{output_path}"
  end
end
