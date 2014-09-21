module MoneroGirl
  class Market
    include Cinch::Plugin

    def refresh_price
      synchronize(:market) do
        @price ||= {}

        refresh(:market, 180) do
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

          resp = RestClient.get("http://data.bter.com/api/1/ticker/xmr_btc")
          @price["Bter"] = {}
          @price["Bter"]["price"] = JSON.parse(resp)["last"].to_f.round(8)
          @price["Bter"]["vol"] = JSON.parse(resp)["vol_xmr"].to_f.round(2)
        end
      end
    end

    match "price", :method => :price
    def price(m)
      return if silence?(m.channel)

      refresh_price
      m.user.msg "Last: #{@price["Poloniex"]["price"]} BTC | Volume: #{@price["Poloniex"]["vol"]} BTC | Poloniex | https://poloniex.com/exchange/btc_xmr"
      m.user.msg "Last: #{@price["HitBTC"]["price"]} BTC | Volume: #{@price["HitBTC"]["vol"]} XMR | HitBTC.com | https://hitbtc.com/terminal#XMRBTC"
      m.user.msg "Last: #{@price["Mintpal"]["price"]} BTC | Volume: #{@price["Mintpal"]["vol"]} BTC | Mintpal | https://www.mintpal.com/market/XMR/BTC"
      m.user.msg "Last: #{@price["Bter"]["price"]} BTC | Volume: #{@price["Bter"]["vol"]} XMR | Bter | https://bter.com/trade/XMR_BTC"
    end

    match /worth (\d+)/, :method => :worth
    def worth(m, amount)
      return if silence?(m.channel)

      refresh_price
      total = amount.to_f * @price["Poloniex"]["price"].to_f
      m.user.msg "#{amount} XMR = #{total} BTC"
    end
  end
end
