.pragma library
.import "RealFetcher.js" as Real

var calls = [];
var pending = [];
var deferred = false;

function clearCache() { pending = []; }
function cancelPending() { pending = []; }
function resetCalls() { calls = []; pending = []; }
function callCount() { return calls.length; }
function lastCall() { return calls.length ? calls[calls.length - 1] : null; }
function preferredText(line, enabled) { return Real.preferredText(line, enabled); }

function setDeferred(value) {
    deferred = value;
    if (!value)
        pending = [];
}

function deliver() {
    var responses = pending;
    pending = [];
    for (var i = 0; i < responses.length; i++)
        responses[i].callback(responses[i].lyrics);
}

function fetchLyrics(source, title, artist, album, duration, onResult) {
    calls.push({ source: source, title: title, artist: artist, album: album, duration: duration });
    var lyrics = [];
    if (title === "Translated Track") {
        lyrics = Real.withTranslations(
            "[00:01]原文一\n[00:02]原文二\n[00:03]原文三",
            source === "lrclib_only" ? "" : "[00:01]译文一\n[00:02]译文二\n[00:03]译文三"
        );
    } else if (title === "Plain Track") {
        lyrics = Real.withTranslations("[00:01]Original One\n[00:02]Original Two", "");
    }
    if (deferred)
        pending.push({ callback: onResult, lyrics: lyrics });
    else
        onResult(lyrics);
}
