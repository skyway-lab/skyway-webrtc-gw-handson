require "net/http"
require "json"
require "socket"

require './util.rb'

def create_data
  #open datasocket for sending data
  res = request(:post, "/data", '{}')
  if res.is_a?(Net::HTTPCreated)
    json = JSON.parse(res.body)
    data_id = json["data_id"]
    ip_v4 = json["ip_v4"]
    port = json["port"]
    [data_id, ip_v4, port]
  else
    # 異常動作の場合は終了する
    p res
    exit(1)
  end
end

def listen_connect_event(peer_id, peer_token, &callback)
  async_get_event("/peers/#{peer_id}/events?token=#{peer_token}", "CONNECTION") { |e|
    data_connection_id = e["data_params"]["data_connection_id"]
    callback.call(data_connection_id)
  }
end

def set_data_redirect(data_connection_id, data_id, redirect_addr, redirect_port)
  params = {
      #for sending data
      "feed_params": {
          "data_id": data_id,
      },
      #for receiving data
      "redirect_params": {
          "ip_v4": redirect_addr,
          "port": redirect_port,
      },
  }

  res = request(:put, "/data/connections/#{data_connection_id}", JSON.generate(params))
  p res
end

def close_data(data_connection_id)
  res = request(:delete, "/data/connections/#{data_connection_id}")
  if res.is_a?(Net::HTTPNoContent)
    # 正常動作の場合NoContentが帰る
  else
    # 異常動作の場合は終了する
    p res
    exit(1)
  end
end