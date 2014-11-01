module MoneroGirl
  class Common
    include Cinch::Plugin

    def refresh_pools
      synchronize(:pools) do
        ctime = File.ctime(POOLS_FILE)

        if (@pools_ctime.nil? || (@pools_ctime != ctime))
          @pools = YAML.load_file(POOLS_FILE)
          @pools_ctime = ctime
        end
      end
    end

    def refresh_stats
      synchronize(:stats) do
        refresh(:stats, 60) do
          url = "http://#{CONFIG["daemon"]["rpc_host"]}:#{CONFIG["daemon"]["rpc_port"]}/json_rpc"
          body = { "jsonrpc" => "2.0", "id" => "test", "method" => "get_info" }
          resp = RestClient.post(url, body.to_json)
          @stats = JSON.parse(resp)["result"]

          url = "http://#{CONFIG["daemon"]["rpc_host"]}:#{CONFIG["daemon"]["rpc_port"]}/json_rpc"
          body = { "jsonrpc" => "2.0", "id" => "test", "method" => "getlastblockheader" }
          resp = RestClient.post(url, body.to_json)
          reward = JSON.parse(resp)["result"]["block_header"]["reward"]
          @stats["last_reward"] = (reward * 0.000000000001).round(2)
        end
      end
    end

    match "help", :method => :help
    def help(m)
      return if silence?(m.channel)

      m.user.msg "Commands: !pools, !worth <amount>, !price, !net, !calc <hashrate>"
    end

    match "pools", :method => :pools
    def pools(m)
      return if silence?(m.channel)

      refresh_pools
      reply = "List of available Monero pools (randomized):\n\n"

      @pools.shuffle.each do |pool|
        name = pool.keys[0]
        reply << "#{name} #{pool[name][1]}, #{pool[name][0]}% fee\n"
      end

      m.user.msg reply
      m.user.msg "Send pull-request with your pool to https://github.com/sammy007/monero_girl"
    end

    match "net", :method => :net
    def net(m)
      return if silence?(m.channel)

      refresh_stats
      diff = @stats["difficulty"]
      nethash = diff / 60.0 / 1000000.0
      m.user.msg "Difficulty: #{diff}, Network hashrate: #{nethash.round(2)} Mh/s"
    end

    match /calc (\d+)/, :method => :calc
    def calc(m, hashrate)
      return if silence?(m.channel)

      refresh_stats
      diff = @stats["difficulty"]
      total = @stats["last_reward"] / (diff / hashrate.to_f / 86400)
      m.user.msg "With #{hashrate} H/s you will mine ~#{total.round(8)} XMR per day"
    end
  end
end
