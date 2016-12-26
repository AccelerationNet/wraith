require "wraith"

class SaveMetadata
  attr_reader :wraith, :history

  def initialize(config, history, file_tag)
    @wraith = config
    @history = history
    @file_tag = file_tag
  end

  def meta_label
    return @file_tag if @file_tag
    return "_latest" if @history
    return ""
  end

  def file_names(width, label, domain_label)
    width = "MULTI" if width.is_a? Array
    "#{wraith.directory}/#{label}/#{width}_#{engine}_#{domain_label}.png"
  end

  def base_label
    "#{wraith.base_domain_label}#{meta_label}"
  end

  def compare_label
    "#{wraith.comp_domain_label}#{meta_label}"
  end

  def engine
    wraith.engine
  end
end
