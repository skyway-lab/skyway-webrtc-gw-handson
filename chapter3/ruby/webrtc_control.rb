require './peer.rb'
require './media.rb'

require "net/http"
require "json"
require "socket"

HOST = "localhost"
PORT = 8000
TARGET_ID = "js"

# create_media, listen_call_event, answer, listen_stream_event, close_media_connection
# はmedia.rbに移動

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

def on_open(peer_id, peer_token)
  (video_id, video_ip, video_port) = create_media(true)
  (data_id, data_ip, data_port) = create_data

  p_id = ""
  mc_id = ""
  th_call = listen_call_event(peer_id, peer_token) {|media_connection_id|
    mc_id = media_connection_id
    answer(media_connection_id, video_id)
    cmd = "gst-launch-1.0 -e rpicamsrc ! video/x-raw,width=640,height=480,framerate=30/1 ! videoconvert ! vp8enc deadline=1  ! rtpvp8pay pt=96 ! udpsink port=#{video_port} host=#{video_ip} sync=false"
    p_id = Process.spawn(cmd)
  }

  dc_id = ""
  th_connect = listen_connect_event(peer_id, peer_token) {|data_connection_id|
    dc_id = data_connection_id
    set_data_redirect(data_connection_id, data_id, "127.0.0.1", 10000)
  }

  th_call.join
  th_connect.join

  [mc_id, dc_id, p_id]
end

if __FILE__ == $0
  if ARGV.length != 1
    p "please input peer id"
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
  media_connection_id = ""
  data_connection_id = ""
  process_id = ""
  th_onopen = listen_open_event(peer_id, peer_token) {|peer_id, peer_token|
    (media_connection_id, data_connection_id, process_id) = on_open(peer_id, peer_token)
  }

  th_onopen.join

  exit_flag = false
  while !exit_flag
    input = STDIN.readline().chomp!
    exit_flag = input == "exit"
  end

  close_media_connection(media_connection_id)
  close_peer(peer_id, peer_token)
  Process.kill(:TERM, process_id)
end
