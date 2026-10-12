// Results use {time: seconds, text: original, translation: supplied translation}.
// Missing translations stay empty; no machine translation is requested.
var _cache = ({});
var _gen = 0;
var _pendingRequests = [];

function clearCache() {
    _cache = ({});
    cancelPending();
}

function cancelPending() {
    _gen++;
    var pending = _pendingRequests.slice();
    for (var i = 0; i < pending.length; i++)
        pending[i]();
}

function parseLrc(text) {
    var out = [];
    var lines = (typeof text === "string" ? text : "").split(/\r?\n/);
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        var times = [];
        var match;
        while ((match = /^\[(\d+):(\d{2}(?:\.\d+)?)\]/.exec(line))) {
            var seconds = Number(match[2]);
            if (seconds < 60)
                times.push(Number(match[1]) * 60 + seconds);
            line = line.substring(match[0].length);
        }
        for (var t = 0; t < times.length; t++)
            out.push({ time: times[t], text: line.trim() });
    }
    out.sort(function (a, b) { return a.time - b.time; });
    var seen = ({});
    return out.filter(function (line) {
        var key = JSON.stringify([line.time, line.text]);
        if (seen[key])
            return false;
        seen[key] = true;
        return true;
    });
}

function withTranslations(original, translated) {
    var lines = parseLrc(original);
    var translations = parseLrc(translated);
    var matches = [];
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        line.translation = "";
        if (!line.text)
            continue;
        for (var j = 0; j < translations.length; j++) {
            var candidate = translations[j];
            if (!candidate.text || candidate.text === "//")
                continue;
            var delta = Math.abs(line.time - candidate.time);
            // Providers can round timestamps differently. Never carry a translation
            // forward to unrelated lines or reuse it for a later original line.
            if (delta <= 0.2 + 1e-9)
                matches.push({ original: i, translated: j, distance: delta });
        }
    }
    matches.sort(function (a, b) {
        // Playback selects the last original when timestamps are equal.
        return a.distance - b.distance || b.original - a.original || a.translated - b.translated;
    });
    var usedOriginals = ({});
    var usedTranslations = ({});
    for (var m = 0; m < matches.length; m++) {
        var match = matches[m];
        if (usedOriginals[match.original] || usedTranslations[match.translated])
            continue;
        usedOriginals[match.original] = true;
        usedTranslations[match.translated] = true;
        var text = translations[match.translated].text;
        if (text !== lines[match.original].text)
            lines[match.original].translation = text;
    }
    return lines;
}

function preferredText(line, translationsEnabled) {
    return line && line.text ? ((translationsEnabled !== false && line.translation) || line.text) : "";
}

function _getJson(url, headers, onJson, onFail) {
    var xhr = new XMLHttpRequest();
    var settled = false;
    var cancel = null;
    var forget = function () {
        var index = _pendingRequests.indexOf(cancel);
        if (index !== -1)
            _pendingRequests.splice(index, 1);
    };
    cancel = function () {
        if (settled)
            return;
        settled = true;
        forget();
        xhr.abort();
    };
    _pendingRequests.push(cancel);
    var fail = function () {
        if (settled)
            return;
        settled = true;
        forget();
        onFail();
    };
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE || settled)
            return;
        if (xhr.status < 200 || xhr.status >= 300) {
            fail();
            return;
        }
        var result;
        try {
            result = JSON.parse(xhr.responseText);
        } catch (e) {
            fail();
            return;
        }
        settled = true;
        forget();
        onJson(result);
    };
    xhr.onerror = fail;
    xhr.open("GET", url);
    if (headers) {
        for (var h in headers)
            xhr.setRequestHeader(h, headers[h]);
    }
    xhr.send();
}

function _fetchNetease(ctx, ok, fail) {
    var query = encodeURIComponent((ctx.title + " " + ctx.artist).trim());
    var headers = { "Referer": "https://music.163.com", "User-Agent": "Mozilla/5.0" };
    var searchUrl = "https://music.163.com/api/search/get?type=1&limit=1&s=" + query;
    _getJson(searchUrl, headers, function (res) {
        if (ctx.gen !== _gen)
            return;
        var songs = res && res.result && res.result.songs;
        if (!songs || songs.length === 0 || songs[0].id === undefined) {
            fail();
            return;
        }
        var lyricUrl = "https://music.163.com/api/song/lyric?id=" + encodeURIComponent(songs[0].id) + "&lv=1&kv=1&tv=-1";
        _getJson(lyricUrl, headers, function (lres) {
            var lyric = lres && lres.lrc && lres.lrc.lyric;
            var translation = lres && lres.tlyric && lres.tlyric.lyric;
            if (typeof lyric === "string")
                ok(lyric, translation);
            else
                fail();
        }, fail);
    }, fail);
}

function _fetchLrclib(title, artist, album, duration, ok, fail) {
    var url = "https://lrclib.net/api/get?track_name=" + encodeURIComponent(title)
            + "&artist_name=" + encodeURIComponent(artist);
    if (album)
        url += "&album_name=" + encodeURIComponent(album);
    if (duration > 0)
        url += "&duration=" + duration;
    _getJson(url, { "User-Agent": "dms-lyrics (https://github.com/Gm-aaa/dms-lyrics)" }, function (res) {
        var synced = res && res.syncedLyrics;
        if (typeof synced === "string")
            ok(synced, "");
        else
            fail();
    }, fail);
}

function _tryChain(order, i, ctx) {
    if (ctx.gen !== _gen)
        return;
    if (i >= order.length) {
        ctx.done([]);
        return;
    }
    var next = function () { _tryChain(order, i + 1, ctx); };
    var ok = function (original, translated) {
        if (ctx.gen !== _gen)
            return;
        var parsed = withTranslations(original, translated);
        if (parsed.some(function (line) { return line.text !== ""; }))
            ctx.done(parsed);
        else
            next();
    };
    if (order[i] === "netease")
        _fetchNetease(ctx, ok, next);
    else
        _fetchLrclib(ctx.title, ctx.artist, ctx.album, ctx.duration, ok, next);
}

function fetchLyrics(source, title, artist, album, duration, onResult) {
    // Even a cache hit must invalidate a previous in-flight track request.
    cancelPending();
    var myGen = _gen;
    var key = JSON.stringify([source, title, artist, album, duration]);
    if (Object.prototype.hasOwnProperty.call(_cache, key)) {
        onResult(_cache[key]);
        return;
    }
    if (!title || !artist) {
        onResult([]);
        return;
    }
    var ctx = {
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        gen: myGen,
        done: function (lyrics) {
            if (myGen !== _gen)
                return;
            _cache[key] = lyrics;
            onResult(lyrics);
        }
    };
    var order;
    switch (source) {
    case "lrclib":       order = ["lrclib", "netease"]; break;
    case "netease_only": order = ["netease"]; break;
    case "lrclib_only":  order = ["lrclib"]; break;
    case "netease":
    default:             order = ["netease", "lrclib"]; break;
    }
    _tryChain(order, 0, ctx);
}
