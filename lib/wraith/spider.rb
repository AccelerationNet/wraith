require "wraith"
require "wraith/helpers/logger"
require "anemone"
require "nokogiri"
require "uri"
require "time"

class Wraith::Spidering
  attr_reader :wraith

  def initialize(wraith)
    @wraith = wraith
  end

  def check_for_paths
    unless wraith.sitemap.nil?
      $logger.info "no paths defined in config, loading paths from sitemap"
      spider = Wraith::Sitemap.new(wraith)
    else
      $logger.info "no paths defined in config, crawling from site root"
      spider = Wraith::Crawler.new(wraith)
    end
    spider.determine_paths
  end
end

class Wraith::Spider
  attr_reader :wraith
  attr_accessor :visits

  def initialize(wraith)
    @wraith = wraith
    @paths = {}
    @visits=0
    @start=Time.new()
  end
  def elapsed ()
    Time.new()-@start
  end

  def determine_paths
    spider
    write_file
  end

  private

  def write_file
    wraith.create_folders()
    File.open(wraith.spider_file, "w+") { |file| file.write(@paths) }
  end

  def pkey (path)
    path == "/" ? "home" : path.gsub("/", "__").chomp("__").downcase
  end
  def path_exists?(path)
    k = pkey(path)
    @paths[k]
  end
  def add_path(path)
    k = pkey(path)
    if path && !@paths[k]
      $logger.debug "Spider adding (#{@paths.count} paths/#{@visits} visits, #{elapsed}s): #{path}"
      @paths[k] = path.downcase
      write_file
    end
  end

  def spider
  end
end

class Wraith::Crawler < Wraith::Spider
  EXT = %w(flv swf png jpg gif asx zip rar tar 7z \
           gz jar js css dtd xsd ico raw mp3 mp4 \
           wav wmv ape aac ac3 wma aiff mpg mpeg \
           avi mov ogg mkv mka asx asf mp2 m1v rtf \
           m3u f4v pdf doc docx xls xlsx ppt pptx pps ppsx bin exe rss xml)

  def spider
    if not expired_crawl?( wraith.spider_file, wraith.spider_days )
      $logger.info "Using existing crawl #{wraith.spider_file} (use --reset)"
      @paths = eval(File.read(wraith.spider_file))
    else
      $logger.info "creating new spider file"
      Anemone.crawl(wraith.base_domain, {
                      :discard_page_bodies=>true,
                      :depth_limit=>wraith.spider_depth}) do |anemone|
        anemone.skip_links_like(/\.(#{EXT.join('|')})$/)
        # Add user specified skips
        anemone.skip_links_like(wraith.spider_skips)
        anemone.focus_crawl { |page|
          links = page.links.select { |link|
            pth = link.path
            rtn = false
            m = pth.match(/\.(#{EXT.join('|')})$/)
            if !m && !path_exists?(pth)
              rtn = true
              add_path(pth)
            end
            # $logger.info "SP: #{link.path} #{rtn} #{ m }"
            rtn
          }
          # $logger.info "Gonna search: #{links}"
          links
        }
        anemone.on_every_page { |page|
          @visits += 1
        }
      end
    end
  end

  def expired_crawl? (file, since)
    return true if !File.exist? file
    exp = (Time.now - File.ctime(file)) / (24 * 3600)
    $logger.debug "Existing #{file} is #{exp}days old"
    exp > since
  end
end

class Wraith::Sitemap < Wraith::Spider
  def spider
    unless wraith.sitemap.nil?
      $logger.info "reading sitemap.xml from #{wraith.sitemap}"
      if wraith.sitemap =~ URI.regexp
        sitemap = Nokogiri::XML(open(wraith.sitemap))
      else
        sitemap = Nokogiri::XML(File.open(wraith.sitemap))
      end
      sitemap.css("loc").each do |loc|
        path = loc.content
        # Allow use of either domain in the sitemap.xml
        wraith.domains.each do |_k, v|
          path.sub!(v, "")
        end
        if wraith.spider_skips.nil? || wraith.spider_skips.none? { |regex| regex.match(path) }
          add_path(path)
        end
      end
    end
  end
end
