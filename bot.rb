require "rubygems"
require "bundler/setup"
require "json"
require "rest-client"
require "cinch"
require "thread"
require "yaml"

CONFIG = YAML.load_file(File.expand_path("config.yml"))
POOLS_FILE = File.expand_path("pools.yml")

LOCK = Mutex.new

def refresh_pools
  LOCK.synchronize do
    ctime = File.ctime(POOLS_FILE)

    if (@pools_ctime.nil? || (@pools_ctime != ctime))
      @pools = YAML.load_file(POOLS_FILE)
      @pools_ctime = ctime
    end
  end
end

def refresh_price
  LOCK.synchronize do
    @price ||= {}

    if (@last_price_update.nil? || (Time.now - @last_price_update > 180))
      resp = RestClient.get("https://poloniex.com/public?command=returnTicker")
      @price["Poloniex"] = {}
      @price["Poloniex"]["price"] = JSON.parse(resp)["BTC_XMR"]["last"].to_f.round(8)
      @price["Poloniex"]["vol"] = JSON.parse(resp)["BTC_XMR"]["baseVolume"].to_f.round(2)

      resp = RestClient.get("http://api.hitbtc.com/api/1/public/XMRBTC/ticker")
      @price["HitBTC"] = {}
      @price["HitBTC"]["price"] = JSON.parse(resp)["last"].to_f.round(8)
      @price["HitBTC"]["vol"] = JSON.parse(resp)["volume"].to_f.round(2)

      resp = RestClient.get("https://api.mintpal.com/v1/market/stats/XMR/BTC")
      @price["Mintpal"] = {}
      @price["Mintpal"]["price"] = JSON.parse(resp)[0]["last_price"].to_f.round(8)
      @price["Mintpal"]["vol"] = JSON.parse(resp)[0]["24hvol"].to_f.round(2)

      @last_price_update = Time.now
    end
  end
end

def refresh_stats
  LOCK.synchronize do
    if (@last_stats_update.nil? || (Time.now - @last_stats_update > 60))
      url = "http://#{CONFIG["daemon"]["rpc_host"]}:#{CONFIG["daemon"]["rpc_port"]}/json_rpc"
      body = { "jsonrpc" => "2.0", "id" => "test", "method" => "get_info" }
      resp = RestClient.post(url, body.to_json)
      @stats = JSON.parse(resp)["result"]

      @last_stats_update = Time.now
    end
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
    c.server = CONFIG["server"]
    c.channels = CONFIG["channels"]
  end

  on :message, "!help" do |m|
    next if silence?(m.channel)

    m.user.msg "Commands: !pools, !worth <amount>, !price, !diff, !calc <hashrate>"
  end

  on :message, "!pools" do |m|
    next if silence?(m.channel)

    refresh_pools
    reply = "List of available Monero pools:\n\n"

    @pools.shuffle.each do |pool|
      name = pool.keys[0]
      reply << "#{name} #{pool[name][1]}, #{pool[name][0]}% fee\n"
    end

    m.user.msg reply
  end

  on :message, "!diff" do |m|
    next if silence?(m.channel)

    refresh_stats
    diff = @stats["difficulty"]
    m.user.msg "Difficulty: #{diff}"
  end

  on :message, "!price" do |m|
    next if silence?(m.channel)

    refresh_price
    m.user.msg "Last: #{@price["Poloniex"]["price"]} BTC | Volume: #{@price["Poloniex"]["vol"]} | Poloniex | https://poloniex.com/exchange/btc_xmr"
    m.user.msg "Last: #{@price["HitBTC"]["price"]} BTC | Volume: #{@price["HitBTC"]["vol"]} | HitBTC.com | https://hitbtc.com/terminal#XMRBTC"
    m.user.msg "Last: #{@price["Mintpal"]["price"]} BTC | Volume: #{@price["Mintpal"]["vol"]} | Mintpal | https://www.mintpal.com/market/XMR/BTC"
  end

  on :message, /^!worth (\d+)/ do |m, amount|
    next if silence?(m.channel)

    refresh_price
    total = amount.to_f * @price["Poloniex"]["price"].to_f
    m.user.msg "#{amount} XMR = #{total} BTC"
  end

  on :message, /^!calc (\d+)/ do |m, hashrate|
    next if silence?(m.channel)

    refresh_stats
    diff = @stats["difficulty"]
    total = 15 / (diff / hashrate.to_f / 86400)
    m.user.msg "With #{hashrate} H/s you will mine ~#{total.round(8)} XMR per day"
  end
end

bot.start
