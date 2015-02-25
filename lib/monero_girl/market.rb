module MoneroGirl
  class Market
    include Cinch::Plugin

    def initialize(bot)
      @markets = {
        "Poloniex" => {
          :name => "Poloniex",
          :url => "https://poloniex.com/exchange/btc_xmr"
        },
        "HitBTC" => {
          :name => "HitBTC.com",
          :url => "https://hitbtc.com/terminal#XMRBTC"
        }
      }
      super(bot)
    end

    def refresh_price
      synchronize(:market) do
        refresh(:market, 180) do
          begin
            resp = RestClient.get("https://poloniex.com/public?command=returnTicker")
            resp = JSON.parse(resp)
            @markets["Poloniex"][:price] = resp["BTC_XMR"]["last"].to_f.round(8)
            @markets["Poloniex"][:vol] = resp["BTC_XMR"]["baseVolume"].to_f.round(2)
          rescue
          end

          begin
            resp = RestClient.get("http://api.hitbtc.com/api/1/public/XMRBTC/ticker")
            resp = JSON.parse(resp)
            @markets["HitBTC"][:price] = resp["last"].to_f.round(8)
            @markets["HitBTC"][:vol] = resp["volume_quote"].to_f.round(2)
          rescue
          end
        end
      end
    end

    match "price", :method => :price
    def price(m)
      return if silence?(m.channel)

      refresh_price

      @markets.each_value do |e|
        next unless e[:price]
        m.user.msg "Last: #{e[:price]} BTC | Volume: #{e[:vol]} BTC | #{e[:name]} | #{e[:url]}"
      end
    end

    match /worth (\d+)/, :method => :worth
    def worth(m, amount)
      return if silence?(m.channel)

      refresh_price

      @markets.each_value do |e|
        next unless e[:price]
        total = amount.to_f * e[:price].to_f
        m.user.msg "#{amount} XMR = #{total} BTC | #{e[:name]}"
      end
    end
  end
end
