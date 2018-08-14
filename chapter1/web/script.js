'use strict';

// Get Parametersを取得するやつ
function getQueryParams() {
    if (1 < document.location.search.length) {
        const query = document.location.search.substring(1);
        const params = query.split('&');

        const result = {};
        for(var param of params) {
            const element = param.split('=');
            const key = decodeURIComponent(element[0]);
            const value = decodeURIComponent(element[1]);
            result[key] = value;
        }
        return result;
    }
    return null;
}

window.onload = ()=> {
    const query = getQueryParams();
    // api keyはGet Parameterから取る
    // これは演習で簡単に設定するための雑な処理で推奨ではない
    const key = query["key"];
    //peer idもGet Parameterから取る
    const peer_id = query["peer_id"]
    const peer = new Peer(peer_id, {
        key: key,
        debug: 3
    });

    peer.on('open', function () {
        // SkyWay Serverに自分のapi keyで繋いでいるユーザ一覧を取得
        let peers = peer.listAllPeers(peers => {
            //JavaScript側で入れたやつとRuby側で入れたやつが出てくればよい
            console.log(peers);
        });
    });

    peer.on('error', function (err) {
        alert(err.message);
    });
};

