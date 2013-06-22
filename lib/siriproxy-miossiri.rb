require 'cora'
require 'siri_objects'
require 'mios'
require 'fuzzy_match'
require 'chronic'

class SiriProxy::Plugin::MiOSsiri < SiriProxy::Plugin
  def initialize(config)
    host = config["mios_host"]

    @mios = MiOS::Interface.new("http://" + host + ":3480")
  end

  def match(input)
    devices = Hash[@mios.devices.map{|d| [d.name, d]}]
    scenes = Hash[@mios.scenes.map{|s| [s.name, s]}]

    matcher = FuzzyMatch.new(devices.merge(scenes), :read => 0)
    return matcher.find(input)[1]
  end

  def find_discrete(input, state)
    case state
    when "on"
     state_match = "off"
    when "off"
     state_match = "on"
    end
    if input.name =~ /#{state_match}$/i
      result = match(input.name.gsub(/#{state_match}/i, state))
    else
      result = input
    end
    return result
  end

  listen_for /(?:^turn on|^activate) (.*)/i do |input|
    result = match(input)
    if result.respond_to?('run!')
      result = find_discrete(result, "on")
      result.run!
      say "Running #{result.name}"
    elsif result.respond_to?('on!') 
      result.on!
      say "Turning on #{result.name}"
    end
    request_completed
  end

  listen_for /(?:^turn off|^deactivate) (.*)/i do |input|
    result = match(input)
    if result.respond_to?('run!')
      result = find_discrete(result, "off")
      result.run!
      say "Running #{result.name}"
    elsif result.respond_to?('off!') 
      result.off!
      say "Turning off #{result.name}"
    end
    request_completed
  end

  listen_for /(?:^set)(.+?)(?:to)(.*)(?:precent)/i do |input, level|
    result = match(input)
    level = Chronic::Numerizer.numerize(level).to_i #ruby-mios checks if the intiger is out of bounds, we'll leave that logic out of here
    if result.respond_to?('set_level!')
      result.set_level!(level)
      say "Setting #{result.name} to #{level} percent"
    else
      say "Sorry, #{result.name} can't be dimmed"
    end
  end
end
