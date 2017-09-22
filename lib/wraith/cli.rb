require "thor"
require "wraith"
require "wraith/save_images"
require "wraith/crop"
require "wraith/spider"
require "wraith/thumbnails"
require "wraith/compare_images"
require "wraith/gallery"
require "wraith/validate"
require "wraith/version"
require "wraith/helpers/logger"
require "wraith/helpers/utilities"

class Wraith::CLI < Thor
  include Thor::Actions


  # This is the magical bit that gets mixed into your classes
  class_option(:config_file, :type => :string, :aliases => "-c",
               :banner =>" the path to your config file")
  class_option :verbose, :type => :boolean
  class_option :debug, :type => :boolean
  class_option(:url, :type =>:string, :aliases => "-u",
               :banner => "The url of the site you wish to render")
  class_option(:ip, :type =>:string, :aliases => "-i",
               :banner => "The ip address to use when grabbing the site (if different from dns - only phantomjs currently - only capture, not spidering)")
  class_option(:directory, :type =>:string, :aliases => "-d",
               :banner => "The base directory you wish to store your actions in")

  attr_accessor :config_name

  def self.source_root
    File.expand_path("../../../", __FILE__)
  end

  # define internal methods which user should not be able to run directly
  no_commands do
    def within_acceptable_limits
      yield
    rescue CustomError => e
      $logger.error e.message
      # other errors, such as SystemError, will not be caught nicely and will give a stack trace (which we'd need)
    end
  end

  desc "validate [wraith]", "checks your configuration and validates that all required properties exist"
  def validate()
    #does by default
  end

  desc "setup", "creates config folder and default config"
  def setup
    within_acceptable_limits do
      directory("templates/configs", "configs")
      directory("templates/javascript", "javascript")
      directory("templates/local", "local")
    end
  end

  desc "reset_shots config", "removes all the files in the shots folder"
  method_option :label, :default=> "", :aliases => "-l", :desc => "label the download eg:(_old)"
  def reset_shots(label=nil)
    label = label or options[:label]
    $logger.info "Removing old shots #{label}"
    within_acceptable_limits do
      if label
        @wraith.remove_labeled_shots label
      else
        @wraith.clear_shots_folder
      end
    end
  end

  desc "setup_folders", "create folders for images"
  def setup_folders()
    @wraith.create_folders
  end

  desc "save_images [history=false] [label=nil]", "captures screenshots"
  def save_images(history = false, label=nil)
    within_acceptable_limits do
      $logger.info "SAVING IMAGES with history:#{history} label:#{label}"
      save_images = Wraith::SaveImages.new(@wraith, history, false, label)
      save_images.save_images
    end
  end

  desc "crop_images", "crops images to the same height"
  def crop_images()
    within_acceptable_limits do
      $logger.info "CROPPING IMAGES"
      crop = Wraith::CropImages.new(@wraith)
      crop.crop_images
    end
  end

  desc "compare_images", "compares images to generate diffs"
  method_option :label1, :default=> "_old", :aliases => "-l", :desc => "label the download eg:(_old)"
  method_option :label2, :default=> "_new", :aliases => "-m", :desc => "label the download eg:(_new)"
  method_option :reset, :default=> false, :type => :boolean, :aliases => "-r", :desc => "remove extant diffs first"
  def compare_images(label1=nil, label2=nil)
    within_acceptable_limits do
      $logger.info "COMPARING IMAGES"
      if options[:reset]
        $logger.debug "Resetting comparisons"
        reset_shots "diff"
      end
      compare = Wraith::CompareImages.new(@wraith, label1||options[:label1], label2||options[:label2])
      compare.compare_images()
      generate_thumbnails()
      generate_gallery()
    end
  end

  desc "generate_thumbnails", "create thumbnails for gallery"
  def generate_thumbnails()
    within_acceptable_limits do
      $logger.info "GENERATING THUMBNAILS"
      thumbs = Wraith::Thumbnails.new(@wraith)
      thumbs.generate_thumbnails
    end
  end

  desc "capture", "Capture paths against two domains, compare them, generate gallery"
  method_option :reset, :default=>false,:type => :boolean, :aliases => "-r", :desc => "Remove existing files first"
  def capture(multi = false)
    within_acceptable_limits do
      reset_shots() if options[:reset]
      @wraith.create_folders
      spider( false )
      save_images()
      crop_images()
      compare_images()
      generate_thumbnails()
      generate_gallery()
    end
  end

  desc "history", "Setup a baseline set of shots same as save-latest-images "
  method_option :label, :default=> "", :aliases => "-l", :desc => "label the download eg:(_old)"
  method_option :reset, :default=>false, :type => :boolean, :aliases => "-r", :desc => "Remove existing files first"
  def history()
    within_acceptable_limits do
      @wraith.create_folders
      if options[:reset]
        reset_shots label || options[:label]
      end
      spider( false )
      save_images(true, label || options[:label])
      generate_thumbnails()
    end
  end

#  -----------------------------------------------------------------
#  NEW CLI
#  _________________________________________________________________

  desc "spider", "Spider the site creating a spider.txt file"
  method_option :reset, :default=> false, :type => :boolean, :aliases => "-r", :desc => "Remove existing files first"
  method_option :label, :default=> nil, :aliases => "-l", :desc => "the download the site to a label eg:(_old)"
  def spider (reset=nil, label=nil)
    label = label || options[:label] || options["label"]
    @wraith.create_folders
    if reset || (reset !=false && options[:reset])
      $logger.info "Removing old spidering"
      @wraith.remove_labeled_shots('spider.txt')
    end
    $logger.info "Spidering #{@wraith.base_domain} into #{@wraith.spider_file} Proxy: #{@wraith.ip} Saving to:#{wraith.spider_save_path('/')} \"#{label}\""
    spider = Wraith::Spidering.new(@wraith, label)
    spider.check_for_paths
  end

  desc "save_latest_images", "get the latest images"
  method_option :label, :default=> "", :aliases => "-l", :desc => "label the download eg:(_old)"
  method_option :reset, :default=> false, :type => :boolean, :aliases => "-r", :desc => "Remove existing files first"
  def save_latest_images (label=nil)
    @wraith.create_folders
    if options[:reset]
      reset_shots label || options[:label]
    end
    spider( false )
    save_images(true, label || options[:label])
    generate_thumbnails()
  end

  desc "generate_gallery", "make a new gallery"
  def generate_gallery ()
    within_acceptable_limits do
      generate_thumbnails()
      $logger.info "GENERATING GALLERY"
      gallery = Wraith::GalleryGenerator.new(@wraith)
      gallery.generate_diff_gallery
    end
  end

  desc "version", "Show the version of Wraith"
  map ["--version", "-version", "-v"] => "version"
  def version
    $logger.info "#{Wraith::VERSION} - #{@wraith.gem_root}"
  end

  attr_reader :wraith
  def initialize(*args)
    super
    $logger.level = (options[:debug] || options[:verbose]) ? Logger::DEBUG : Logger::INFO
    $logger.debug "options:#{options}"

    @wraith = Wraith::Wraith.new(config_dict=options)
    # not sure this should maybe be "latest"
    $logger.info Wraith::Validate.new(@wraith).validate
    @wraith.debug = (options[:debug] || options[:verbose])
    $logger.debug("Starting with config: %s" % [@wraith.config])
  end
end
