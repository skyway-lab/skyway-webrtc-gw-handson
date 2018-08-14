require "net/http"
require "json"
require "socket"

HOST = "localhost"
PORT = 8000

def parse_response(json)
  if json.is_a?(Net::HTTPCreated)
    JSON.parse(json.body)
  elsif json.is_a?(Net::HTTPOK)
    JSON.parse(json.body)
  elsif json.is_a?(Net::HTTPAccepted)
    JSON.parse(json.body)
  elsif json.is_a?(String)
    JSON.parse(json)
  else
    json
  end
end

def request(method_name, uri, *args)
  response = nil
  Net::HTTP.start(HOST, PORT) { |http|
    response = http.send(method_name, uri, *args)
  }
  response
end

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

#GET http://35.200.46.204/#/1.peers/peer_event を叩きPeerイベントを取得する
def wait_thread_for(uri, event, ended)
  e = nil
  thread_event = Thread.new do
    # timeoutする場合があるのでその時はやり直す
    while e == nil or e["event"] != event
      res = request(:get, uri)
      # Status Code 200で以下のようなJSONが帰ってくるのでparseする
      # {
      #   "event"=>EVENT_NAME,
      #   "params"=> OBJEDT
      # }
      if res.is_a?(Net::HTTPOK)
        e = JSON.parse(res.body)
      end
    end
    if ended
      ended.call(e)
    end
  end.run
  thread_event
end

def on_open(peer_id, peer_token)
  thread_event = wait_thread_for("/peers/#{peer_id}/events?token=#{peer_token}", "OPEN", lambda { |e|
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
  })
  thread_event.join
  [peer_id, peer_token]
end

if __FILE__ == $0
  if ARGV.length != 1
    exit(0)
  end
  # 自分のPeer IDは実行時引数で受け取っている
  peer_id = ARGV[0]

  # SkyWayのAPI KEYは盗用を避けるためハードコーディングせず環境変数等から取るのがbetter
  skyway_api_key = ENV['API_KEY']

  # SkyWay WebRTC GatewayにPeer作成の指示を与える
  # 以降、作成したPeer Objectは他のユーザからの誤使用を避けるためtokenを伴って操作する
  peer_token = create_peer(skyway_api_key, peer_id)
  # WebRTC GatewayがSkyWayサーバへ接続し、Peerとして認められると発火する
  # この時点で初めてSkyWay Serverで承認されて正式なpeer_idとなる
  peer_info = on_open(peer_id, peer_token)

  sleep(100);
end
