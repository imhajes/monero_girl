require "rubygems"
require "bundler/setup"
require "json"
require "rest-client"
require "cinch"
require "thread"
require "yaml"

lib = File.expand_path("../lib/", __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require "monero_girl"

CONFIG = YAML.load_file(File.expand_path("config.yml"))
POOLS_FILE = File.expand_path("pools.yml")
$memo = {}

def refresh(key, seconds)
  if ($memo[key].nil? || (Time.now - $memo[key] > seconds))
    puts "refreshing #{key}"
    yield
    $memo[key] = Time.now
  end
end

def silence?(channel)
  return false if channel.nil? # private message

  CONFIG["silencers"].each do |nick|
    return true if channel.has_user?(nick)
  end

  false
end

bot = Cinch::Bot.new do
  configure do |c|
    c.nick = CONFIG["nick"]
    c.password = CONFIG["password"]
    c.server = CONFIG["server"]
    c.channels = CONFIG["channels"]
    c.plugins.plugins = [MoneroGirl::Common, MoneroGirl::Market]
  end
end

bot.start
