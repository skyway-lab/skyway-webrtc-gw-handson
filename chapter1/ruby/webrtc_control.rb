require "net/http"
require "json"
require "socket"

require './peer.rb'

HOST = "localhost"
PORT = 8000

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
  th_onopen = listen_open_event(peer_id, peer_token) {|peer_id, peer_token|
    p peer_id
    p peer_token
  }
  th_onopen.join

  exit_flag = false
  while !exit_flag
    input = STDIN.readline().chomp!
    exit_flag = input == "exit"
  end

  close_peer(peer_id, peer_token)
end
