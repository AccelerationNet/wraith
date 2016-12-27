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
  include Logging

  # This is the magical bit that gets mixed into your classes
  class_option :config, :type => :string, :required=> true, :aliases => "-c"
  class_option :verbose, :type => :boolean
  class_option :debug, :type => :boolean

  attr_accessor :config_name

  def self.source_root
    File.expand_path("../../../", __FILE__)
  end

  # define internal methods which user should not be able to run directly
  no_commands do
    def within_acceptable_limits
      yield
    rescue CustomError => e
      logger.error e.message
      # other errors, such as SystemError, will not be caught nicely and will give a stack trace (which we'd need)
    end

    def check_for_paths()
      spider = Wraith::Spidering.new(@wraith)
      spider.check_for_paths
    end
  end

  desc "validate [wraith]", "checks your configuration and validates that all required properties exist"
  def validate()
    within_acceptable_limits do
      logger.info Wraith::Validate.new(@wraith).validate
    end
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
    label = options[:label] or label
    logger.info "Removing old shots #{label}"
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
      logger.info "SAVING IMAGES with history:#{history} label:#{label}"
      save_images = Wraith::SaveImages.new(@wraith, history, false, label)
      save_images.save_images
    end
  end

  desc "crop_images", "crops images to the same height"
  def crop_images()
    within_acceptable_limits do
      logger.info "CROPPING IMAGES"
      crop = Wraith::CropImages.new(@wraith)
      crop.crop_images
    end
  end

  desc "compare_images", "compares images to generate diffs"
  method_option :label1, :default=> "", :aliases => "-l1", :desc => "label the download eg:(_old)"
  method_option :label2, :default=> "", :aliases => "-l2", :desc => "label the download eg:(_new)"
  def compare_images(label1=nil, label2=nil)
    within_acceptable_limits do
      logger.info "COMPARING IMAGES"
      compare = Wraith::CompareImages.new(@wraith, label1||options[:label1], label2||options[:label2])
      compare.compare_images
    end
  end

  desc "generate_thumbnails", "create thumbnails for gallery"
  def generate_thumbnails()
    within_acceptable_limits do
      logger.info "GENERATING THUMBNAILS"
      thumbs = Wraith::Thumbnails.new(@wraith)
      thumbs.generate_thumbnails
    end
  end

  desc "generate_gallery", "create page for viewing images"
  def generate_gallery()
    within_acceptable_limits do
      logger.info "GENERATING GALLERY"
      gallery = Wraith::GalleryGenerator.new(@wraith)
      gallery.generate_gallery
    end
  end

  desc "capture", "Capture paths against two domains, compare them, generate gallery"
  method_option :reset, :default=>false, :aliases => "-r", :desc => "Remove existing files first"
  def capture(multi = false)
    within_acceptable_limits do
      logger.info Wraith::Validate.new(@wraith).validate("capture")
      reset_shots() if options[:reset]
      @wraith.create_folders
      check_for_paths(config)
      save_images()
      crop_images()
      compare_images()
      generate_thumbnails()
      generate_gallery()
    end
  end

  desc "history", "Setup a baseline set of shots"
  method_option :reset, :default=>false, :aliases => "-r", :desc => "Remove existing files first"
  def history()
    within_acceptable_limits do
      logger.info Wraith::Validate.new(@wraith).validate("history")
      reset_shots() if options[:reset]
      check_for_paths()
      @wraith.create_folders
      save_images()
      copy_old_shots()
    end
  end

#  -----------------------------------------------------------------
#  NEW CLI
#  _________________________________________________________________

  desc "spider", "Spider the site creating a spider.txt file"
  method_option :reset, :default=> false, :aliases => "-r", :desc => "Remove existing files first"
  def spider (label=nil)
    logger.info Wraith::Validate.new(@wraith).validate("latest")
    spider = Wraith::Spidering.new(@wraith)
    spider.check_for_paths
  end

  desc "save_latest_images", "get the latest images"
  method_option :label, :default=> "", :aliases => "-l", :desc => "label the download eg:(_old)"
  method_option :reset, :default=> false, :aliases => "-r", :desc => "Remove existing files first"
  def save_latest_images (label=nil)
    logger.info Wraith::Validate.new(@wraith).validate("latest")
    if options[:reset]
      reset_shots label || options[:label]
    end
    check_for_paths()
    @wraith.create_folders
    save_images(true, label || options[:label])
    generate_thumbnails()
  end

  desc "compare_latest_images", "get the latest images"
  method_option :label1, :default=> "", :aliases => "-l1", :desc => "label the download eg:(_old)"
  method_option :label2, :default=> "", :aliases => "-l2", :desc => "label the download eg:(_new)"
  def compare_latest_images (label1=nil, label2=nil)
    logger.info Wraith::Validate.new().validate("latest")
    compare_images(label1||options[:label1], label2||options[:label2])
    generate_thumbnails()
  end

  desc "compare_latest_images", "get the latest images"
  def latest_thumbnails ()
    logger.info Wraith::Validate.new(@wraith).validate("latest")
    generate_thumbnails()
  end

  desc "latest_gallery", "make a new gallery"
  def latest_gallery ()
    logger.info Wraith::Validate.new().validate("latest")
    within_acceptable_limits do
      generate_thumbnails()
      logger.info "GENERATING GALLERY #{config}"
      gallery = Wraith::GalleryGenerator.new(@wraith)
      gallery.generate_diff_gallery
    end
  end

  desc "latest", "Capture new shots to compare with baseline"
  method_option :reset, :default=> false, :aliases => "-r", :desc => "Remove existing files first"
  def latest()
    within_acceptable_limits do
      logger.info Wraith::Validate.new(@wraith).validate("latest")
      reset_shots() if options[:reset]
      save_images(true)
      copy_base_images()
      crop_images()
      compare_images()
      generate_thumbnails()
      generate_gallery()
    end
  end

  desc "version", "Show the version of Wraith"
  map ["--version", "-version", "-v"] => "version"
  def version
    logger.info Wraith::VERSION
  end

  attr_reader :wraith
  def initialize(*args)
    super
    @wraith = Wraith::Wraith.new(options[:config])
    logger.debug "options:#{options}"
    logger.level = (options[:debug] || options[:verbose]) ? Logger::DEBUG : Logger::INFO
  end
end
