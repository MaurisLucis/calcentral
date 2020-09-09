require_relative '../../lib/calcentral_config'
require 'yaml'

module ServerConfig
  extend self

  def get_settings(source_file)

    if File.exist?(source_file)
      source = YAML.load(ERB.new(IO.read(source_file.to_s)).result)
    end
    source ||= false

    settings = CalcentralConfig.deep_open_struct(source)
    settings
  end
end
