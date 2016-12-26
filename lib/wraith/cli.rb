require "thor"
require "wraith"
require "wraith/save_images"
require "wraith/crop"
require "wraith/spider"
require "wraith/folder"
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

    def check_for_paths(config_name)
      spider = Wraith::Spidering.new(config_name)
      spider.check_for_paths
    end

    def copy_old_shots(config_name)
      create = Wraith::FolderManager.new(config_name)
      create.copy_old_shots
    end
  end

  desc "validate [config_name]", "checks your configuration and validates that all required properties exist"
  def validate(config_name)
    within_acceptable_limits do
      logger.info Wraith::Validate.new(config_name).validate
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

  desc "reset_shots [config_name]", "removes all the files in the shots folder"
  method_option :label, :default=> "", :aliases => "-l", :desc => "label the download eg:(_old)"
  def reset_shots(config_name, label=nil)
    label = options[:label] or label
    logger.info "Removing old shots #{label}"
    within_acceptable_limits do
      reset = Wraith::FolderManager.new(config_name)
      if label
        reset.remove_labeled_shots label
      else
        reset.clear_shots_folder
      end
    end
  end

  desc "setup_folders [config_name]", "create folders for images"
  def setup_folders(config_name)
    within_acceptable_limits do
      create = Wraith::FolderManager.new(config_name)
      create.create_folders
    end
  end

  desc "copy_base_images [config_name]", "copies the required base images over for comparison with latest images"
  def copy_base_images(config_name)
    within_acceptable_limits do
      copy = Wraith::FolderManager.new(config_name)
      copy.copy_base_images
    end
  end

  desc "save_images [config_name] [histore=false] [label=nil]", "captures screenshots"
  def save_images(config_name, history = false, label=nil)
    within_acceptable_limits do
      logger.info "SAVING IMAGES with history:#{history} label:#{label}"
      save_images = Wraith::SaveImages.new(config_name, history, false, label)
      save_images.save_images
    end
  end

  desc "crop_images [config_name]", "crops images to the same height"
  def crop_images(config_name)
    within_acceptable_limits do
      logger.info "CROPPING IMAGES"
      crop = Wraith::CropImages.new(config_name)
      crop.crop_images
    end
  end

  desc "compare_images [config_name]", "compares images to generate diffs"
  method_option :label1, :default=> "", :aliases => "-l1", :desc => "label the download eg:(_old)"
  method_option :label2, :default=> "", :aliases => "-l2", :desc => "label the download eg:(_new)"
  def compare_images(config_name, label1=nil, label2=nil)
    within_acceptable_limits do
      logger.info "COMPARING IMAGES"
      compare = Wraith::CompareImages.new(config_name, label1||options[:label1], label2||options[:label2])
      compare.compare_images
    end
  end

  desc "generate_thumbnails [config_name]", "create thumbnails for gallery"
  def generate_thumbnails(config_name)
    within_acceptable_limits do
      logger.info "GENERATING THUMBNAILS"
      thumbs = Wraith::Thumbnails.new(config_name)
      thumbs.generate_thumbnails
    end
  end

  desc "generate_gallery [config_name]", "create page for viewing images"
  def generate_gallery(config_name, multi = false)
    within_acceptable_limits do
      logger.info "GENERATING GALLERY"
      gallery = Wraith::GalleryGenerator.new(config_name, multi)
      gallery.generate_gallery
    end
  end

  desc "capture [config_name]", "Capture paths against two domains, compare them, generate gallery"
  method_option :reset, :default=>false, :aliases => "-r", :desc => "Remove existing files first"
  def capture(config, multi = false)
    within_acceptable_limits do
      logger.info Wraith::Validate.new(config).validate("capture")
      reset_shots(config) if options[:reset]
      check_for_paths(config)
      setup_folders(config)
      save_images(config)
      crop_images(config)
      compare_images(config)
      generate_thumbnails(config)
      generate_gallery(config, multi)
    end
  end

  desc "multi_capture [filelist]", "A Batch of Wraith Jobs"
  def multi_capture(filelist)
    within_acceptable_limits do
      config_array = IO.readlines(filelist)
      config_array.each do |config|
        capture(config.chomp, true)
      end
    end
  end

  desc "history [config_name]", "Setup a baseline set of shots"
  method_option :reset, :default=>false, :aliases => "-r", :desc => "Remove existing files first"
  def history(config)
    within_acceptable_limits do
      logger.info Wraith::Validate.new(config).validate("history")
      reset_shots(config) if options[:reset]
      check_for_paths(config)
      setup_folders(config)
      save_images(config)
      copy_old_shots(config)
    end
  end

  desc "save_latest_images [config_name]", "get the latest images"
  method_option :label, :default=> "", :aliases => "-l", :desc => "label the download eg:(_old)"
  method_option :reset, :default=> false, :aliases => "-r", :desc => "Remove existing files first"
  def save_latest_images (config, label=nil)
    logger.info Wraith::Validate.new(config).validate("latest")
    if options[:reset]
      reset_shots config, label || options[:label]
    end
    save_images(config, true, label || options[:label])
  end

  desc "compare_latest_images [config_name]", "get the latest images"
  method_option :label1, :default=> "", :aliases => "-l1", :desc => "label the download eg:(_old)"
  method_option :label2, :default=> "", :aliases => "-l2", :desc => "label the download eg:(_new)"
  def compare_latest_images (config, label1=nil, label2=nil)
    logger.info Wraith::Validate.new(config).validate("latest")
    compare_images(config, label1||options[:label1], label2||options[:label2])
  end

  desc "compare_latest_iamges [config_name]", "get the latest images"
  def latest_thumbnails (config)
    logger.info Wraith::Validate.new(config).validate("latest")
    generate_thumbnails(config)
  end

  desc "latest_gallery [config_name]", "make a new gallery"
  def latest_gallery (config)
    logger.info Wraith::Validate.new(config).validate("latest")
    within_acceptable_limits do
      logger.info "GENERATING GALLERY #{config}"
      gallery = Wraith::GalleryGenerator.new(config, false)
      gallery.generate_diff_gallery
    end
  end

  desc "latest [config_name]", "Capture new shots to compare with baseline"
  method_option :reset, :default=> false, :aliases => "-r", :desc => "Remove existing files first"
  def latest(config)
    within_acceptable_limits do
      logger.info Wraith::Validate.new(config).validate("latest")
      reset_shots(config) if options[:reset]
      save_images(config, true)
      copy_base_images(config)
      crop_images(config)
      compare_images(config)
      generate_thumbnails(config)
      generate_gallery(config)
    end
  end

  desc "test_logging [config_name]", "tests the logging"
  method_option :level, :default=>Logger::WARN, :desc=> "the level the logger writes at"
  def test_logging (config=nil)
    puts "--- In test logger ---"
    logger.info "Testing the logger at: #{logger.level}"
    logger.debug "Debug: Testing the logger at: #{logger.level}"
  end

  desc "version", "Show the version of Wraith"
  map ["--version", "-version", "-v"] => "version"
  def version
    logger.info Wraith::VERSION
  end

  def initialize(*args)
    super
    logger.debug "options:#{options}"
    logger.level = options[:debug]||options[:verbose] ? Logger::DEBUG : Logger::INFO
  end
end
