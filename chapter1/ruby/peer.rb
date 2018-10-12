require "net/http"
require "json"
require "socket"

require './util.rb'

# POST http://35.200.46.204/#/1.peers/peer を叩きPeerの割当を行う
def create_peer(key, peer_id)
  params = {
      "key": key,
      "domain": "localhost",
      "turn": false,
      "peer_id": peer_id,
  }
  res = request(:post, "/peers", JSON.generate(params))
  if res.is_a?(Net::HTTPCreated)
    # 正常に動作している場合、Status Code 201で以下のようなJSONが帰ってくる
    # {
    #   "command_type": "PEERS_CREATE",
    #   "params": {
    #     "peer_id": "ID_FOO",
    #     "token": "pt-9749250e-d157-4f80-9ee2-359ce8524308"
    #   }
    # }
    json = JSON.parse(res.body)
    json["params"]["token"]
  else
    # 異常動作の場合は終了する
    p res
    exit(1)
  end
end

def listen_open_event(peer_id, peer_token, &callback)
  async_get_event("/peers/#{peer_id}/events?token=#{peer_token}", "OPEN") {|e|
    # 以下のようなJSONが帰ってくるのでpeer_id, tokenを取得
    #{
    #   "event"=>"OPEN",
    #   "params"=>{
    #     "peer_id"=>PEER_ID,
    #     "token"=>TOKEN
    #   }
    # }
    peer_id = e["params"]["peer_id"]
    peer_token = e["params"]["token"]
    if callback
      callback.call(peer_id, peer_token)
    end
  }
end

def close_peer(peer_id, peer_token)
  res = request(:delete, "/peers/#{peer_id}?token=#{peer_token}")
  if res.is_a?(Net::HTTPNoContent)
    # 正常動作の場合NoContentが帰る
  else
    # 異常動作の場合は終了する
    p res
    exit(1)
  end
end